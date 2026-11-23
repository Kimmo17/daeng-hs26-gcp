# agent: Triage einer fehlgeschlagenen Pipeline

Cloud-Run-Job `triage`: bekommt die ID einer fehlgeschlagenen Execution des Workflows
`gtfs-pipeline`, liest mit zehn Lese-Werkzeugen nach (Execution, Jobs und ihre Logs, Audit-Log,
Scan-Spezifikation und -Ergebnisse, Builds, Load-Jobs, BigQuery lesend), und schreibt eine Diagnose
als Zeile nach `ops.incidents`: Kategorie, was geschah, wo nachschauen, Fakten, Schlüsse, Ursache,
vorgeschlagene Massnahme, Konfidenz. Er führt nichts aus.

Dateien: `main.py` (Schema, Anweisung, Agent, Lauf), `tools.py` (die Werkzeuge), `requirements.txt`,
`Dockerfile`, `SPEC.md` (was der Agent darf und was nicht).

Aufruf als Job: `gcloud run jobs execute triage --region europe-west6 --args <execution-id>`.
Selbsttest der Rollen: `--args --selftest`.

Umgebungsvariablen: `GOOGLE_CLOUD_PROJECT`, `GOOGLE_CLOUD_LOCATION` (Vertex, `eu`),
`GOOGLE_GENAI_USE_VERTEXAI=1`. Optional `MODEL` (Standard `gemini-3.8-flash`), `PIPELINE_REGION`,
`WORKFLOW_NAME`, `DATASCAN_NAME`, `PIPELINE_JOBS`, `OPS_DATASET`, `MAX_LLM_CALLS` (Standard 30),
`OPS_WRITE=0` zum Testen ohne Schreiben.

Rollen des Service-Accounts `triage-sa`, alle auf dem Projekt, ausser der letzten:
`roles/workflows.viewer`, `roles/run.viewer`, `roles/logging.viewer`,
`roles/dataplex.dataScanDataViewer`, `roles/cloudbuild.builds.viewer`, `roles/bigquery.jobUser`,
`roles/bigquery.metadataViewer`, `roles/bigquery.resourceViewer`, `roles/aiplatform.user`, und
`roles/bigquery.dataEditor` nur auf dem Dataset `ops`. Keine Leserolle auf `raw`: der Agent sieht
Zeilenzahlen und Metadaten, keine Daten.
