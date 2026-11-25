SPEZIFIKATION PIPELINE (Wiederholbarkeit)

Ziel: Eine neue Lieferung der Garage Keller wird als Ordner garage/data/version=JJJJ-MM-TT/ ins Git gelegt. Ein einziger Befehl bringt sie in die Cloud und baut die Marts neu, ohne dbt auf dem Laptop:

    bash garage/neue-version.sh JJJJ-MM-TT

Jede Version bleibt in Storage und BigQuery erhalten. Die Marts zeigen immer die neueste vollständige Version. Ein zweiter Lauf mit derselben Version ändert nichts. Eine fehlerhafte Lieferung stoppt, bevor sie die Marts erreicht. Das Projekt ist Abgabe in einem BI-Modul: deutsche Kommentare, die sagen warum, nicht was; ein main.py ohne Klassen.

Begriff Lieferung: Jede Version ist ein vollständiger Stand aller vier Listen (Snapshot), alte Zeilen bleiben, neue kommen dazu. Deshalb wertet dbt nie mehrere Versionen zusammen aus, sonst würden Zeilen doppelt gezählt.

Was gleich bleibt: garage/ingest/load.sh und die Abgabe aus Woche 9 bleiben unverändert im Repo (lokaler Weg, dokumentiert). Neue Ordner: garage/ingest-job/, garage/pipeline/, garage/neue-version.sh. Geändert wird nur garage/transform/.

1. Schema der Lieferung: garage/ingest-job/schema.json
Für jede der vier Dateien Dateiname, Tabellenname und die erwarteten Spalten in Reihenfolge, genau wie in den Kopfzeilen von version=2026-11-17: ds01_terminbuch.csv -> terminbuch, ds02_reifenhotel.csv -> reifenhotel, data01_anfragen.csv -> anfragen, data02_anrufe.csv -> anrufe. Diese eine Datei benutzen sowohl der Job als auch neue-version.sh, damit die Schema-Prüfung an beiden Orten dieselbe ist.

2. Cloud-Run-Job garage-ingest (garage/ingest-job/: main.py, schema.json, requirements.txt mit google-cloud-bigquery>=3,<4 und google-cloud-storage>=3,<4, Dockerfile python:3.12-slim mit CMD python main.py, README.md mit zehn Zeilen)
Konfiguration über Umgebungsvariablen: VERSION (Pflicht, JJJJ-MM-TT, ohne Standardwert, fehlt sie: Abbruch), BUCKET (Standard <projekt>-raw), DATASET (Standard garage_raw), LOCATION (Standard europe-west6). Identität: garage-ingest-sa mit Lesezugriff auf den Bucket, Schreibzugriff auf garage_raw und bigquery.jobUser im Projekt, sonst nichts.
Ablauf, als vier Schritte im Code erkennbar:
  a) Lieferung prüfen: Unter gs://BUCKET/garage/version=VERSION/ liegen genau die vier Dateien aus schema.json. Für jede Datei die Kopfzeile lesen (BOM und Zeilenende entfernen) und mit schema.json vergleichen. Bei jeder Abweichung Abbruch mit einer Meldung, die Datei, erwartete und gefundene Spalten nennt. Erst wenn alle vier stimmen, wird geladen.
  b) Laden: Für jede Datei ein Load-Job in die Partition DATASET.<tabelle>$JJJJMMTT (Ingestion-Time-Partitionierung nach Tag, Partition-Decorator aus VERSION). Tabelle anlegen, falls sie fehlt, ohne Ablauf der Partitionen. Schema explizit aus schema.json, alle Spalten STRING, kein Autodetect, Kopfzeile überspringen. Schreibmodus WRITE_TRUNCATE, damit ein zweiter Lauf genau diese Partition ersetzt und sonst nichts.
  c) Mengen prüfen: Zeilen in der eben geladenen Partition zählen. Eine leere Partition ist ein Fehler.
  d) Protokoll: Für jede Tabelle eine Zeile in DATASET.ladeprotokoll (version DATE, tabelle STRING, zeilen INT64, quelle STRING mit gs-Pfad, geladen_um TIMESTAMP). Tabelle anlegen, falls sie fehlt. Das Protokoll ist ein Log: jeder Lauf fügt Zeilen an.
Logging auf stdout, eine Zeile pro Ereignis: "Lieferung version=<v>: 4 Dateien, Schema ok", pro Tabelle "<tabelle>$<JJJJMMTT>  <n> Zeilen", am Ende "Fertig: version=<v> in <projekt>.<dataset>". Fehler nicht abfangen: Der Job endet bei einem Fehler mit Exit-Code ungleich null, darauf baut der Workflow.

3. Transformation als Cloud-Run-Job garage-transform (Änderungen in garage/transform/)
  a) Makro neueste_version(): ermittelt zur Compile-Zeit per run_query die grösste version aus garage_raw.ladeprotokoll, für die alle vier Tabellen protokolliert sind (COUNT(DISTINCT tabelle) = 4), und gibt sie als Datumsliteral zurück. Ist die dbt-Variable version gesetzt (dbt build --vars '{version: "2026-11-17"}'), gilt diese. So lässt sich jede ältere Version reproduzieren. Das Makro schreibt die gewählte Version ins dbt-Log.
  b) Jedes Staging-Modell filtert die Quelle mit _PARTITIONDATE = {{ neueste_version() }} (Literal, damit nur eine Partition gelesen wird) und führt die Spalte datenversion (DATE) mit. Jeder Mart führt datenversion als Spalte. Sonst bleibt die Logik unverändert.
  c) sources.yml: ladeprotokoll als fünfte Quelle mit Beschreibung.
  d) Neuer harter Test: jeder Mart hat genau eine datenversion.
  e) Dockerfile: python:3.12-slim, requirements installieren, Projekt kopieren, CMD dbt build --profiles-dir . --target prod. .venv, target und logs gehören nicht ins Image (.dockerignore).
  f) Job garage-transform mit Umgebungsvariable DBT_PROJECT, Identität garage-transform-sa mit Lesezugriff auf garage_raw, Schreibzugriff auf garage_staging, garage_intermediate, garage_marts und bigquery.jobUser im Projekt, sonst nichts.

4. Workflow garage-pipeline (garage/pipeline/workflow.yaml, garage/pipeline/README.md)
Eingabe {"version": "JJJJ-MM-TT"}. Ohne version: Abbruch mit klarer Meldung. Schritte: (1) Job garage-ingest mit Override der Umgebungsvariable VERSION starten und warten. (2) Nur wenn (1) gelungen ist: Job garage-transform starten und warten. (3) Ergebnis zurückgeben: version und die Namen beider Executions. Scheitert ein Schritt, endet der Workflow mit einem Fehler, der Transform-Job läuft dann nicht und die Marts behalten die letzte gute Version. Keine Wiederholungen, keine Parallelität. Projekt und Region zur Laufzeit aus der Umgebung des Workflows, keine IDs im Code. Identität garage-pipeline-sa mit roles/run.jobsExecutorWithOverrides auf beiden Jobs (Invoker reicht nicht, weil der Ingest mit einer überschriebenen Umgebungsvariable startet) und logging.logWriter, sonst nichts.

5. Befehl garage/neue-version.sh JJJJ-MM-TT (bash, set -euo pipefail)
  a) Format des Datums prüfen; Ordner garage/data/version=<datum>/ muss existieren und genau die vier Dateien aus schema.json enthalten; jede Kopfzeile muss mit schema.json übereinstimmen. Sonst Abbruch, bevor irgendetwas hochgeladen wird.
  b) Git als Quelle: Der Ordner muss committet sein (keine uncommitteten Änderungen in diesem Ordner). Sonst Abbruch mit dem Hinweis, zuerst zu committen. Ist der Branch dem Remote voraus, nur eine Warnung ausgeben.
  c) Versionen sind unveränderlich: Liegt die Version schon im Bucket, die Prüfsummen der vier Dateien vergleichen (gcloud storage hash und gcloud storage objects describe). Gleich: nicht nochmals hochladen, weiter mit d). Verschieden: Abbruch mit dem Hinweis, eine neue Version mit neuem Datum anzulegen. Neu: die vier Dateien nach gs://<projekt>-raw/garage/version=<datum>/ kopieren.
  d) Workflow garage-pipeline mit {"version": "<datum>"} starten und auf das Ende warten. Bei Fehler: Meldung und Exit-Code ungleich null.
  e) Zum Schluss mart_wartezeit_woche abfragen und als Tabelle ausgeben (iso_woche, n_anfragen, mittlere_wartezeit, datenversion).

6. Zeitplan: keiner. Lieferungen entstehen von Hand beim Abtippen; ein Zeitplan würde Automatik vortäuschen. Begründung in garage/pipeline/README.md.

Akzeptanzkriterien (Zahlen aus den synthetischen Lieferungen, unabhängig nachgerechnet):
- Nach dem Lauf von version=2026-11-17: ladeprotokoll hat vier Zeilen für 2026-11-17; garage_raw: terminbuch 199, reifenhotel 189, anfragen 104, anrufe 10 Zeilen in der Partition 20261117; die drei Marts zeigen genau die Werte aus garage/ABNAHME.md, mit datenversion 2026-11-17.
- Nach dem Lauf von version=2026-12-14: Partition 20261214 mit terminbuch 404, reifenhotel 192, anfragen 211, anrufe 20 Zeilen; Partition 20261117 unverändert vorhanden. mart_wartezeit_woche hat vier Zeilen, alle mit datenversion 2026-12-14: Woche 47: 60 / 60 / 2.92 / 0.80 / 0.100 / 0; Woche 48: 44 / 42 / 2.64 / 0.57 / 0.182 / 2; Woche 49: 58 / 57 / 2.79 / 0.56 / 0.086 / 1; Woche 50: 49 / 49 / 3.06 / 0.80 / 0.143 / 0 (n_anfragen / n_mit_wartezeit / mittlere_wartezeit / mittlere_verschiebung / ablehnungsquote / n_unplausibel). mart_termine_tag: 40 Zeilen, Summe 199 + 205 = 404, kleinster Tag 7, grösster 13. mart_erfassung_tag: 20 Zeilen, "prüfen" genau am 17.11., 24.11., 25.11., 03.12. und 04.12.2026.
- Zweiter Lauf von 2026-12-14: keine Datei wird hochgeladen, Zeilenzahlen und Marts unverändert.
- Nochmals 2026-11-17 starten, nachdem 2026-12-14 geladen ist: Marts bleiben auf datenversion 2026-12-14.
- Lokal reproduzierbar: dbt build --vars '{version: "2026-11-17"}' ergibt wieder die Werte aus ABNAHME.md. Danach wieder den Job garage-transform laufen lassen, damit die Marts auf der neuesten Version stehen.
- Negativtests: (1) Eine Kopie von 2026-12-14 als version=2099-01-01 mit umbenannter Spalte in data01_anfragen.csv: neue-version.sh bricht vor dem Hochladen ab. (2) Workflow direkt mit version 2099-01-02 starten, die es im Bucket nicht gibt: garage-ingest scheitert, garage-transform startet nicht, die Marts bleiben auf 2026-12-14. Die Testordner danach löschen, nichts davon committen.

Nicht tun: keinen Zeitplan, keinen Dataplex-Scan, keinen Alarm (nicht Teil dieser Aufgabe), keine Eventarc- oder Cloud-Build-Trigger, keine Dienste ausserhalb der erlaubten Liste in CLAUDE.md, keine Schlüsseldateien, keinen neuen Bucket, keine Änderung an Dateien ausserhalb von garage/, keine Zahlen hart codieren, die als Variable vorgesehen sind, bestehende Partitionen anderer Versionen nicht anfassen.
