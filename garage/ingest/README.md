`load.sh` lädt eine Version der synthetischen Garage-Keller-Daten aus `garage/data/version=<datum>/`.
Es prüft die vier CSV-Dateien und kopiert sie unverändert nach `gs://<projekt>-raw/garage/version=<datum>/`.
Dann lädt es sie mit `--replace` in die Tabellen `garage_raw.terminbuch`, `reifenhotel`, `anfragen`, `anrufe` (alle Spalten STRING).
Start aus dem Repo-Ordner: `bash garage/ingest/load.sh 2026-11-17` (Projekt aus `gcloud config get-value project`).
Am Schluss gibt es die Zeilenzahl jeder Tabelle aus; ein zweiter Lauf mit demselben Datum ergibt dieselben Zahlen.
