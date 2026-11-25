"""Ingest-Job garage-ingest: lädt eine Lieferung der Garage Keller aus dem Bucket nach garage_raw.

Die vier Schritte stehen in main(). Die Spezifikation steht in garage/SPEC-PIPELINE.md, Teile 1 und 2.
"""

import csv
import json
import os
import re
import sys
from datetime import datetime, timezone
from pathlib import Path

from google.cloud import bigquery, storage

# Ohne Standardwert: ein Job, der still eine falsche Version lädt, ist schlimmer als einer, der abbricht.
VERSION = os.environ.get("VERSION", "")
DATASET = os.environ.get("DATASET", "garage_raw")
LOCATION = os.environ.get("LOCATION", "europe-west6")

# Dieselbe Datei prüft auch neue-version.sh, damit Laptop und Cloud nie verschiedene Regeln haben.
SCHEMA = json.loads((Path(__file__).parent / "schema.json").read_text(encoding="utf-8"))["dateien"]

# Die Kopfzeile ist kurz; 64 KB reichen sicher und ersparen das Herunterladen der ganzen Datei.
KOPF_BYTES = 64 * 1024


def log(message):
    # flush, damit die Zeile sofort in Cloud Logging erscheint und nicht erst beim Beenden.
    print(message, flush=True)


def kopfzeile(blob):
    roh = blob.download_as_bytes(start=0, end=KOPF_BYTES - 1)
    # utf-8-sig entfernt ein BOM, splitlines das Zeilenende, egal ob Excel \r\n geschrieben hat.
    erste_zeile = roh.decode("utf-8-sig", errors="replace").splitlines()[0]
    return [spalte.strip() for spalte in next(csv.reader([erste_zeile]))]


def lieferung_pruefen(bucket, prefix):
    gefunden = {b.name.removeprefix(prefix) for b in bucket.list_blobs(prefix=prefix)}
    erwartet = {d["datei"] for d in SCHEMA}
    # Fehlende und überzählige Dateien sind beide verdächtig: eine halbe oder fremde Lieferung soll nicht laden.
    if gefunden != erwartet:
        sys.exit(
            f"Abbruch: gs://{bucket.name}/{prefix} enthält nicht genau die vier erwarteten Dateien. "
            f"Fehlt: {sorted(erwartet - gefunden)}, zu viel: {sorted(gefunden - erwartet)}"
        )
    for d in SCHEMA:
        spalten = kopfzeile(bucket.blob(prefix + d["datei"]))
        if spalten != d["spalten"]:
            sys.exit(
                f"Abbruch: Kopfzeile von {d['datei']} weicht von schema.json ab. "
                f"Erwartet: {d['spalten']}, gefunden: {spalten}"
            )


def tabelle_anlegen(bq, tabelle, spalten):
    table = bigquery.Table(
        f"{bq.project}.{DATASET}.{tabelle}",
        schema=[bigquery.SchemaField(s, "STRING") for s in spalten],
    )
    # Kein Ablauf: jede Version ist eine Lieferung, die man später reproduzieren können soll.
    table.time_partitioning = bigquery.TimePartitioning(type_=bigquery.TimePartitioningType.DAY)
    bq.create_table(table, exists_ok=True)


def laden(bq, uri, tabelle, spalten, decorator):
    job_config = bigquery.LoadJobConfig(
        source_format=bigquery.SourceFormat.CSV,
        skip_leading_rows=1,
        encoding="UTF-8",
        # Alles STRING und kein Autodetect: die Rohschicht hält fest, was kam; Typen setzt erst dbt.
        schema=[bigquery.SchemaField(s, "STRING") for s in spalten],
        autodetect=False,
        # Ersetzt nur die Partition dieser Version, ein zweiter Lauf erzeugt also keine Duplikate.
        write_disposition=bigquery.WriteDisposition.WRITE_TRUNCATE,
        time_partitioning=bigquery.TimePartitioning(type_=bigquery.TimePartitioningType.DAY),
    )
    ziel = f"{bq.project}.{DATASET}.{tabelle}${decorator}"
    bq.load_table_from_uri(uri, ziel, job_config=job_config, location=LOCATION).result()


def zeilen_zaehlen(bq, tabelle):
    # Gezählt wird, was jetzt in der Partition liegt, nicht was der Load-Job meldet: das prüft das Ergebnis.
    sql = f"SELECT COUNT(*) AS n FROM `{bq.project}.{DATASET}.{tabelle}` WHERE _PARTITIONDATE = @version"
    job_config = bigquery.QueryJobConfig(
        query_parameters=[bigquery.ScalarQueryParameter("version", "DATE", VERSION)]
    )
    n = next(iter(bq.query(sql, job_config=job_config, location=LOCATION).result())).n
    if n == 0:
        sys.exit(f"Abbruch: {tabelle}${VERSION.replace('-', '')} ist nach dem Laden leer.")
    return n


def protokollieren(bq, eintraege):
    schema = [
        bigquery.SchemaField("version", "DATE"),
        bigquery.SchemaField("tabelle", "STRING"),
        bigquery.SchemaField("zeilen", "INT64"),
        bigquery.SchemaField("quelle", "STRING"),
        bigquery.SchemaField("geladen_um", "TIMESTAMP"),
    ]
    table_id = f"{bq.project}.{DATASET}.ladeprotokoll"
    bq.create_table(bigquery.Table(table_id, schema=schema), exists_ok=True)
    # Load-Job statt Streaming: die Zeilen sind sofort vollständig sichtbar, und dbt liest gleich danach.
    # WRITE_APPEND, weil das Protokoll jeden Lauf festhält, auch die Wiederholung einer Version.
    job_config = bigquery.LoadJobConfig(
        schema=schema,
        write_disposition=bigquery.WriteDisposition.WRITE_APPEND,
    )
    bq.load_table_from_json(eintraege, table_id, job_config=job_config, location=LOCATION).result()


def main():
    if not re.fullmatch(r"\d{4}-\d{2}-\d{2}", VERSION):
        sys.exit(f"Abbruch: Umgebungsvariable VERSION muss JJJJ-MM-TT sein, ist aber '{VERSION}'.")
    # Prüft auch, ob es das Datum gibt: 2026-02-30 soll nicht als Partition enden.
    datetime.strptime(VERSION, "%Y-%m-%d")
    decorator = VERSION.replace("-", "")

    bq = bigquery.Client()
    bucket_name = os.environ.get("BUCKET", f"{bq.project}-raw")
    bucket = storage.Client(project=bq.project).bucket(bucket_name)
    prefix = f"garage/version={VERSION}/"

    # Schritt a: Lieferung prüfen, bevor irgendetwas in BigQuery geschrieben wird
    lieferung_pruefen(bucket, prefix)
    log(f"Lieferung version={VERSION}: {len(SCHEMA)} Dateien, Schema ok")

    geladen_um = datetime.now(timezone.utc).isoformat()
    eintraege = []
    for d in SCHEMA:
        uri = f"gs://{bucket_name}/{prefix}{d['datei']}"

        # Schritt b: in die Partition der Version laden
        tabelle_anlegen(bq, d["tabelle"], d["spalten"])
        laden(bq, uri, d["tabelle"], d["spalten"], decorator)

        # Schritt c: Mengen prüfen
        n = zeilen_zaehlen(bq, d["tabelle"])
        log(f"{d['tabelle']}${decorator}  {n} Zeilen")

        eintraege.append(
            {"version": VERSION, "tabelle": d["tabelle"], "zeilen": n, "quelle": uri, "geladen_um": geladen_um}
        )

    # Schritt d: Protokoll erst am Schluss, damit nur eine vollständig geladene Version vier Einträge hat
    protokollieren(bq, eintraege)

    # Kein try/except: ein Fehler beendet den Job mit Exit-Code ungleich null, darauf baut der Workflow.
    log(f"Fertig: version={VERSION} in {bq.project}.{DATASET}")


if __name__ == "__main__":
    main()
