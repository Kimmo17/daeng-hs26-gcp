SPEZIFIKATION INGEST

Ziel: Die vier CSV-Dateien unter garage/data/version=2026-11-17/ wiederholbar nach Cloud Storage und BigQuery laden. Die Daten sind synthetisch und klein (unter 500 Zeilen). Deshalb kein Cloud-Run-Job, sondern ein Shell-Skript, das man lokal startet. Es soll für eine spätere Version (z. B. version=2026-12-01) nur mit einem anderen Argument laufen.

Datei: garage/ingest/load.sh (bash, set -euo pipefail, deutsche Kommentare, die sagen warum) und garage/ingest/README.md (fünf Zeilen: was das Skript tut, wie man es startet).

Aufruf: bash garage/ingest/load.sh 2026-11-17

Projekt: aus gcloud config get-value project. Bucket: der vorhandene Bucket <projekt>-raw. Kein neuer Bucket.

Schritte im Skript:
1. Prüfen, dass der Ordner garage/data/version=<datum>/ existiert und genau die vier Dateien enthält: ds01_terminbuch.csv, ds02_reifenhotel.csv, data01_anfragen.csv, data02_anrufe.csv. Sonst abbrechen.
2. Die vier Dateien unverändert nach gs://<projekt>-raw/garage/version=<datum>/ kopieren (gcloud storage cp). Rohdaten bleiben dort liegen, auch wenn spätere Versionen kommen.
3. Dataset garage_raw in europe-west6 anlegen, falls es fehlt (bq mk), mit der Beschreibung "Rohdaten Garage Keller, synthetisch".
4. Jede Datei aus dem Bucket in eine Tabelle laden, mit bq load --replace --source_format=CSV --skip_leading_rows=1 und einem ausdrücklichen Schema, in dem jede Spalte STRING ist. Tabellennamen: terminbuch, reifenhotel, anfragen, anrufe. Spaltennamen genau wie in der Kopfzeile der CSV. Typen werden erst in dbt gesetzt, damit ein Formatfehler sichtbar wird statt beim Laden zu verschwinden.
5. Jeder Tabelle die Beschreibung "SYNTHETISCH, version=<datum>" und das Label datenstatus=synthetisch geben.
6. Zum Schluss für jede Tabelle die Zeilenzahl ausgeben.

Akzeptanzkriterien: garage_raw.terminbuch 199 Zeilen, reifenhotel 189, anfragen 104, anrufe 10. Ein zweiter Lauf mit demselben Datum ergibt dieselben Zeilenzahlen (keine Duplikate). Im Bucket liegen unter garage/version=2026-11-17/ genau vier Dateien.

Nicht tun: keinen Cloud-Run-Job, keinen Scheduler, keine Typumwandlung beim Laden (kein Autodetect), keinen neuen Bucket, keine Partitionierung, keine Dateien ausserhalb von garage/ ändern.
