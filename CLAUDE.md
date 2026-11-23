# Regeln für Claude Code in diesem Repo

Kurs: ZHAW Data Engineering, GCP-Lektionen. Die Person, mit der du arbeitest, hat wenig Erfahrung mit Google Cloud. Erkläre jeden Befehl in einem Satz, bevor du ihn ausführst. Antworte auf Deutsch und sprich die Person mit du an.

## Abrechnung
- Benutze nur das Rechnungskonto mit "Education" im Namen (Education-Guthaben). Andere Rechnungskonten fasst du nicht an.
- Erstelle nie ein Rechnungskonto, starte nie einen Free Trial, frage nie nach Kreditkartendaten.
- Aktiviere keine anderen Dienste als die in der Liste unten.

## Befehle
- Zeige jeden Befehl, der etwas erstellt, ändert oder löscht, bevor du ihn ausführst.
- Vor jeder BigQuery-Abfrage auf eine Tabelle, die wir nicht selbst angelegt haben: zuerst `bq query --dry_run`, und nenne die Bytes.
- Lösche nichts ohne ausdrückliche Bestätigung in diesem Chat. Keine --quiet Flags bei Lösch-Befehlen.
- Wenn ein Befehl fehlschlägt: zeige die Fehlermeldung, erkläre sie, schlage einen Fix vor, führe ihn nicht automatisch aus.
- Lies den Ordner `referenz/` nur, wenn die Person es ausdrücklich verlangt.
- Lies den Ordner `docs/` nur, wenn die Person es ausdrücklich verlangt. Die Tutorials sind für die Person geschrieben, du arbeitest aus dem Prompt und aus dem Code.

## Projekt
- Standardprojekt: das Ergebnis von `gcloud config get-value project`. Region: europe-west6. BigQuery-Location: europe-west6.
- Erlaubte APIs: cloudresourcemanager, serviceusage, cloudbilling, billingbudgets, iam, storage, bigquery, run, cloudbuild, artifactregistry, cloudscheduler, logging, monitoring, datalineage, dataplex, dataform, workflows, workflowexecutions, bigqueryconnection, aiplatform.
- Sprachmodell (Lektion 3): nur gemini-3.8-flash, nur über die BigQuery-Verbindung vertex-ai und die URL der EU-Multiregion, kein CREATE MODEL, kein Kurzname als Endpunkt.
- Kein Dataflow, Composer, Dataproc, Datastream, keine Compute-Engine-VMs. Wenn du meinst, eines davon sei nötig, sag es und stoppe.

## Ordner
- `ingest/` Cloud-Run-Job, der die Daten lädt
- `alerts/` Cloud-Run-Job, der die Bahnverkehrsinformationen der SBB lädt (Lektion 3)
- `transform/` dbt-Projekt, entsteht in Lektion 2 aus transform/SPEC.md, wächst in Lektion 3 um transform/SPEC-ALERTS.md
- `referenz/` Musterlösungen. Lies diesen Ordner nur, wenn die Person es ausdrücklich verlangt.
- `checks/` Dataplex Data-Quality-Regeln
- `pipeline/` Workflows (einer mit Qualitätsschranke für den Fahrplan, einer für die Meldungen, und ab Lektion 4 die Fassung des Fahrplan-Workflows mit Triage) und Alarm
- `agent/` Cloud-Run-Job triage, der Agent, der eine fehlgeschlagene Execution untersucht (Lektion 4)
- `incidents/` drei Vorfälle zum Nachstellen (Lektion 4)
- `docs/` Tutorials für die Person. Lies diesen Ordner nur, wenn die Person es ausdrücklich verlangt.

## Lektion 4
- `incidents/` enthält Befehle, die die Pipeline absichtlich kaputt machen. Führe sie nur aus, wenn die Person es in diesem Chat ausdrücklich verlangt, und sag vorher in einem Satz, was kaputtgeht.
- Der Agent in `agent/` liest nur. Schlage kein Werkzeug vor, das etwas schreibt, deployt, startet oder löscht, und gib `triage-sa` keine Rolle, die nicht in `agent/README.md` steht.
- In `ops.incidents` schreibt der Job triage. Du änderst dort nur `status`, `closed_by` und `closed_at`, und nur auf Verlangen.
- Den Job triage startest du nur mit einer Execution-ID oder mit `--selftest` als Argument, nie ohne Argument.
