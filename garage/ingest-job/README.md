# garage-ingest

Cloud-Run-Job, der eine Lieferung aus `gs://<projekt>-raw/garage/version=JJJJ-MM-TT/` nach `garage_raw` lädt. Spezifikation: `garage/SPEC-PIPELINE.md`, Teile 1 und 2.

- `schema.json`: die vier Dateien, ihre Tabellen und Spalten; dieselbe Datei prüft `garage/neue-version.sh`.
- Ablauf in `main.py`: (a) Lieferung prüfen, (b) in die Partition `<tabelle>$JJJJMMTT` laden, (c) Zeilen zählen, (d) `ladeprotokoll` ergänzen.
- Umgebung: `VERSION` (Pflicht), `BUCKET` (Standard `<projekt>-raw`), `DATASET` (`garage_raw`), `LOCATION` (`europe-west6`).
- Identität: `garage-ingest-sa`, Objekt-Leser auf dem Bucket, Data Editor auf `garage_raw`, Job User im Projekt.
- Ein zweiter Lauf derselben Version ersetzt nur deren Partitionen; das Protokoll bekommt vier weitere Zeilen.
- Start von Hand: `gcloud run jobs execute garage-ingest --region=europe-west6 --update-env-vars=VERSION=JJJJ-MM-TT --wait`
