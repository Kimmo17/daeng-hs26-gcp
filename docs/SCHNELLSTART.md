# Schnellstart: der Stand nach Lektion 2 in einer Stunde

Für alle, die bei Lektion 3 oder 4 einsteigen, ohne Lektion 1 und 2 gemacht zu haben. Und
für alle, die ein frisches Projekt brauchen, in dem die Pipeline schon läuft. Du baust hier
in acht Prompts auf, was Lektion 1 und 2 in zwei Nachmittagen aufbauen, ohne die Erklärungen
dazwischen. Was du dabei überspringst, steht am Ende mit Verweisen, lies es nach, wenn die
Pipeline läuft.

Am Ende hast du in deinem Projekt: einen Job, der den Schweizer Fahrplan lädt, zwei
Versionen davon in BigQuery, einen Qualitäts-Scan, einen Job, der daraus die Fahrten pro
Linie und Tag der Verkehrsbetriebe Luzern baut, einen Workflow, der die drei verbindet und
bei schlechten Daten stoppt, einen Zeitplan, und einen Alarm per E-Mail. Genau das, worauf
Lektion 3 und 4 aufbauen.

Zeit: rund eine Stunde, davon gut 30 Minuten Warten auf Builds und Läufe. Jeder Prompt sagt,
wie lange.

Drei Dinge sind anders als in Lektion 1 und 2, und alle drei sind Absicht: Die Transformation
kommt aus der Musterlösung `referenz/transform/`, statt dass du sie aus der Spezifikation
erzeugen lässt. Der Zeitplan zeigt von Anfang an auf den Workflow, den Umweg über einen
Zeitplan für den Ingest-Job allein gibt es nicht. Und die APIs für Lektion 3 und 4 sind
gleich mit dabei.

## Voraussetzungen

[VORBEREITUNG.md](VORBEREITUNG.md), Schritte 1 bis 3: Claude Code installiert und
eingeloggt, gcloud installiert und mit dem ZHAW-Konto eingeloggt, das Repo geklont, das
Google-Cloud-Plugin installiert. Das ist eine Viertelstunde, und sie lässt sich nicht
abkürzen. Der Education-Coupon muss eingelöst sein.

Dann im Terminal, im Ordner `daeng-hs26-gcp`:

```bash
git pull
gcloud auth login
gcloud auth application-default login
claude
```

Hast du auf diesem Rechner schon andere Google-Cloud-Projekte: Lege vor den zwei Logins
eine eigene gcloud-Konfiguration an, `gcloud config configurations create daeng`. Sonst
biegt Schritt 1 deine bestehende Konfiguration auf das Kursprojekt um. Auf einem frischen
Rechner spielt das keine Rolle.

Wie in den Lektionen: Prompt einfügen, jeden Befehl lesen und mit der Liste darunter
vergleichen, freigeben. Sperrt der Auto-Modus einen Befehl, zeigt Claude Code ihn dir mit
`!` am Anfang, dann liest du ihn und führst ihn selbst aus. Die IDs in den Befehlslisten
sind bei dir andere, die Struktur ist dieselbe.

---

## 1. Projekt

Ersetze `KÜRZEL` durch dein ZHAW-Kürzel in Kleinbuchstaben. Vier Minuten.

```text
Lege mein Google-Cloud-Projekt für den Kurs an. Halte dich an diese Regeln:
- Zeige mir jeden Befehl, bevor du ihn ausführst, und erkläre ihn in einem Satz.
- Erstelle kein Rechnungskonto, starte keinen Free Trial, frage nie nach Kreditkartendaten.
- Wenn ein Schritt nicht das erwartete Ergebnis liefert, stoppe und frag mich.

Mein Kürzel: KÜRZEL

Schritte:
1. Führe `gcloud billing accounts list` aus. Nimm das offene Rechnungskonto mit "Education"
   im Namen und merke dir seine ID. Gibt es keins, stoppe. Gibt es daneben weitere offene
   Konten, benutze sie nicht, aber nenne sie mir.
2. Erstelle ein Projekt mit der ID daeng-KÜRZEL-XXXX, wobei XXXX vier zufällige
   Kleinbuchstaben oder Ziffern sind. Setze es als Standardprojekt, auch für die Application
   Default Credentials.
3. Verknüpfe das Projekt mit dem Rechnungskonto aus Schritt 1.
4. Aktiviere diese APIs im Projekt: cloudresourcemanager, serviceusage, cloudbilling,
   billingbudgets, iam, storage, bigquery, run, cloudbuild, artifactregistry, cloudscheduler,
   logging, monitoring, datalineage, dataplex, dataform, workflows, workflowexecutions,
   bigqueryconnection, aiplatform (jeweils mit .googleapis.com).
5. Setze europe-west6 als Standardregion für Cloud Run. Schalte keine weitere API ein,
   auch nicht, wenn gcloud danach fragt.
6. Lege einen Bucket an: Name ist die Projekt-ID plus "-raw", Region europe-west6,
   einheitlicher Zugriff auf Bucket-Ebene.
7. Lege die Service Agents für Dataplex und Workflows an (gcloud beta services identity
   create), in einem frischen Projekt gibt es sie noch nicht.
8. Lies mit `gcloud billing accounts describe` die Währung des Rechnungskontos. Erstelle für
   das Rechnungskonto ein Budget daeng-budget über 50 in dieser Währung, Warnungen bei 50,
   90 und 100 Prozent, credit-types-treatment exclude-all-credits, ohne Filter auf das
   Projekt. Scheitert der Befehl mit USER_PROJECT_DENIED, ist die Budget-API noch nicht
   überall aktiv: warte drei Minuten und wiederhole ihn unverändert.
9. Zeige mir zum Schluss: Projekt-ID, Projektnummer, Rechnungskonto und Währung, die
   Anzahl aktivierter APIs, den Bucket, das Budget.
```

Befehle:

```bash
gcloud billing accounts list
gcloud projects create daeng-KÜRZEL-XXXX --name="DAENG GCP"
gcloud config set project daeng-KÜRZEL-XXXX
gcloud auth application-default set-quota-project daeng-KÜRZEL-XXXX
gcloud billing projects link daeng-KÜRZEL-XXXX --billing-account=XXXXXX-XXXXXX-XXXXXX
gcloud services enable cloudresourcemanager.googleapis.com serviceusage.googleapis.com \
  cloudbilling.googleapis.com billingbudgets.googleapis.com iam.googleapis.com \
  storage.googleapis.com bigquery.googleapis.com run.googleapis.com \
  cloudbuild.googleapis.com artifactregistry.googleapis.com cloudscheduler.googleapis.com \
  logging.googleapis.com monitoring.googleapis.com datalineage.googleapis.com \
  dataplex.googleapis.com dataform.googleapis.com workflows.googleapis.com \
  workflowexecutions.googleapis.com bigqueryconnection.googleapis.com \
  aiplatform.googleapis.com
gcloud config set run/region europe-west6
gcloud storage buckets create gs://daeng-KÜRZEL-XXXX-raw --location=europe-west6 \
  --uniform-bucket-level-access
gcloud beta services identity create --service=dataplex.googleapis.com
gcloud beta services identity create --service=workflows.googleapis.com
gcloud billing accounts describe XXXXXX-XXXXXX-XXXXXX
gcloud billing budgets create --billing-account=XXXXXX-XXXXXX-XXXXXX \
  --display-name="daeng-budget" --budget-amount=50CHF \
  --credit-types-treatment=exclude-all-credits \
  --threshold-rule=percent=0.5 --threshold-rule=percent=0.9 --threshold-rule=percent=1.0
```

Bei Punkt 3 und 8 kann Claude Code stoppen und dir den Befehl zum Selbst-Ausführen geben,
weil es Änderungen an Rechnungskonten als heikel einstuft. Dann führst du ihn im Terminal
aus und sagst Claude Code, dass es weitermachen soll. `50CHF` ist bei dir `50USD`, wenn das
Rechnungskonto in Dollar abrechnet. Das Budget gilt für das ganze Rechnungskonto, nicht nur
für dieses Projekt, das ist Absicht: Legst du aus Versehen ein zweites Projekt an, warnt es
trotzdem. Das Budget kommt als letzter Punkt, weil die Budget-API nach dem Einschalten ein
paar Minuten braucht, bis sie für das Projekt gilt.

Checkpoint: In der Console steht oben links `daeng-KÜRZEL-XXXX`, und
[Cloud Storage](https://console.cloud.google.com/storage/browser) zeigt den Bucket.

---

## 2. Der Ingest-Job

Der Job in `ingest/` holt den Fahrplan als Zip vom Publisher, legt die Zip im Bucket ab und
lädt die Tabellen nach BigQuery, eine Partition pro Feed-Version. Sieben Minuten: drei für
den Build, zweieinhalb für den ersten Lauf.

```text
Lege einen Service-Account ingest-sa an, warte, bis describe ihn zeigt, und gib ihm genau
drei Rechte: BigQuery Data Editor und BigQuery Job User auf dem Projekt, Storage Object
Admin nur auf dem Bucket <projekt-id>-raw. Gib dem Compute-Standardkonto des Projekts
(Projektnummer-compute@developer.gserviceaccount.com) die Rolle Cloud Run Builder auf dem
Projekt. Lege in Artifact Registry eine Docker-Ablage cloud-run-source-deploy in
europe-west6 an. Deploye dann ingest/ als Cloud-Run-Job ingest-gtfs in europe-west6, gebaut
aus dem Quellcode, mit ingest-sa, 2 GiB Speicher, 1 CPU, 30 Minuten Timeout, ohne
Wiederholung. Starte den Job einmal und warte auf das Ende. Zeige mir die letzten zehn
Logzeilen.
```

Befehle:

```bash
gcloud iam service-accounts create ingest-sa --display-name="Ingest-Job GTFS"
gcloud iam service-accounts describe ingest-sa@daeng-KÜRZEL-XXXX.iam.gserviceaccount.com
gcloud projects add-iam-policy-binding daeng-KÜRZEL-XXXX \
  --member="serviceAccount:ingest-sa@daeng-KÜRZEL-XXXX.iam.gserviceaccount.com" \
  --role="roles/bigquery.dataEditor"
gcloud projects add-iam-policy-binding daeng-KÜRZEL-XXXX \
  --member="serviceAccount:ingest-sa@daeng-KÜRZEL-XXXX.iam.gserviceaccount.com" \
  --role="roles/bigquery.jobUser"
gcloud storage buckets add-iam-policy-binding gs://daeng-KÜRZEL-XXXX-raw \
  --member="serviceAccount:ingest-sa@daeng-KÜRZEL-XXXX.iam.gserviceaccount.com" \
  --role="roles/storage.objectAdmin"
gcloud projects add-iam-policy-binding daeng-KÜRZEL-XXXX \
  --member="serviceAccount:PROJEKTNUMMER-compute@developer.gserviceaccount.com" \
  --role="roles/run.builder"
gcloud artifacts repositories create cloud-run-source-deploy \
  --repository-format=docker --location=europe-west6
gcloud run jobs deploy ingest-gtfs --source ingest --region europe-west6 \
  --service-account=ingest-sa@daeng-KÜRZEL-XXXX.iam.gserviceaccount.com \
  --memory=2Gi --cpu=1 --task-timeout=30m --max-retries=0
gcloud run jobs execute ingest-gtfs --region europe-west6 --wait
```

Die letzte Logzeile lautet `Fertig: Version 2026MMDD in daeng-KÜRZEL-XXXX.raw`, davor acht
Zeilen mit Tabelle, Partition und Zeilenzahl, `stop_times` mit über 40 Millionen.

Checkpoint: Execution grün, acht Tabellen im Dataset `raw`.

---

## 3. Eine zweite Version

Die Transformation und der Scan sollen mit mehreren Versionen umgehen, also lädst du eine
ältere nach. Das ist der einzige Prompt mit einer Angabe, die du selbst holst, Claude Code
kann sie nicht nachschlagen, die Katalog-API der Seite ist für Skripte gesperrt. Zuerst die
URL, dann der Prompt:

Öffne https://data.opentransportdata.swiss/dataset/timetable-2026-gtfs2020. Links steht
die Liste der Versionen, die neueste zuoberst, die hat der Job in Schritt 2 geladen. Klick
auf die zweitneueste, `GTFS_FP2026_2026MMTT.zip`. Auf ihrer Seite steht unter dem Titel ein
Feld "URL:" mit einem Link, der auf `/download/gtfs_fp2026_2026MMTT.zip` endet. Das ist die
Download-URL, kopiere sie (Rechtsklick, "Link kopieren", der Knopf "Herunterladen" hat
denselben Link) und setze sie im Prompt anstelle von `URL-DER-ÄLTEREN-VERSION` ein. Die
Adresse der Seite selbst (`.../resource/<id>` ohne `/download/`) ist es nicht, damit lädt
der Job eine HTML-Seite und bricht ab. Vergisst du den Platzhalter, fragt Claude Code nach
der URL, dann schickst du sie ihm im Chat. Drei Minuten.

```text
Starte den Job ingest-gtfs einmal mit einer anderen Quelle, nur für diese eine Execution,
ohne den Job dauerhaft zu ändern: SOURCE_URL=URL-DER-ÄLTEREN-VERSION
Warte auf das Ende. Zeige mir dann, nur lesend, pro Tabelle die Partitionen mit Zeilenzahl
aus INFORMATION_SCHEMA.PARTITIONS.
```

Befehle:

```bash
gcloud run jobs execute ingest-gtfs --region europe-west6 --wait \
  --update-env-vars SOURCE_URL=URL-DER-ÄLTEREN-VERSION
bq query --use_legacy_sql=false \
  'SELECT table_name, partition_id, total_rows
   FROM raw.INFORMATION_SCHEMA.PARTITIONS
   WHERE partition_id != "__NULL__" ORDER BY 1, 2'
```

Checkpoint: Zwei Partitionen pro Tabelle, `trips` mit je rund 2.6 Millionen Zeilen.

---

## 4. Der Qualitäts-Scan

`checks/trips_quality.yaml` hat fünf Regeln auf `raw.trips`. Die Datei nennt die Projekt-ID
der Musterlösung, Claude Code ersetzt sie durch deine. Diese Änderung bleibt in deinem Klon
und wird nie committet, und Lektion 4 braucht sie so. Drei Minuten.

```text
Ersetze in checks/trips_quality.yaml die Projekt-ID daeng-pect-olw5 überall durch meine
Projekt-ID, sonst nichts. Die Änderung bleibt in meinem Klon: nicht committen, nicht
zurücksetzen, auch nicht am Ende. Lege das Dataset checks in europe-west6 an. Lege einen
Dataplex-Data-Quality-Scan trips-quality in europe-west6 auf die Tabelle raw.trips an, mit
dem Regelwerk checks/trips_quality.yaml, das Anlegen dauert zwei bis drei Minuten. Starte
den Scan, warte bis er fertig ist, und zeige mir das Ergebnis pro Regel.
```

Befehle:

```bash
bq mk --location=europe-west6 checks
gcloud dataplex datascans create data-quality trips-quality --location=europe-west6 \
  --data-source-resource="//bigquery.googleapis.com/projects/daeng-KÜRZEL-XXXX/datasets/raw/tables/trips" \
  --data-quality-spec-file=checks/trips_quality.yaml
gcloud dataplex datascans run trips-quality --location=europe-west6
gcloud dataplex datascans jobs list --datascan=trips-quality --location=europe-west6
gcloud dataplex datascans jobs describe JOB-ID --datascan=trips-quality \
  --location=europe-west6 --view=FULL
```

Beim Anlegen des Scans zeigt gcloud zwei bis drei Minuten lang nur eine Reihe Punkte. Das
ist kein Hänger, nicht abbrechen. Bei den zwei SQL-Regeln fehlt im Ergebnis das Feld
`assertionRowCount`: Dataplex lässt es weg, wenn es 0 ist, und 0 heisst keine Verstösse.

Checkpoint: fünf Regeln, alle `passed: true`, und `git status` zeigt
`checks/trips_quality.yaml` als geändert. So bleibt es.

---

## 5. Die Transformation

In Lektion 2 lässt man Claude Code das dbt-Projekt aus `transform/SPEC.md` erzeugen und
liest es. Hier nimmst du die Musterlösung aus `referenz/`. Claude Code fasst diesen Ordner
nur an, wenn du es ausdrücklich verlangst, darum steht es so im Prompt. Fünf Minuten: drei
für den Build, eine für dbt.

```text
Kopiere die Musterlösung referenz/transform/ vollständig nach transform/ (cp -r
referenz/transform/. transform/), das verlange ich ausdrücklich. Committe nichts. Lege
einen Service-Account transform-sa an, warte, bis describe ihn zeigt, und gib ihm
genau zwei Rechte auf dem Projekt: BigQuery Data Editor und BigQuery Job User. Deploye
transform/ als Cloud-Run-Job transform-gtfs in europe-west6, gebaut aus dem Quellcode, mit
transform-sa, 1 GiB Speicher, 1 CPU, 20 Minuten Timeout, ohne Wiederholung, mit der
Umgebungsvariable DBT_PROJECT auf meine Projekt-ID. Starte den Job und warte auf das Ende.
Zeige mir die letzten 40 Zeilen des Logs und danach, nur lesend, aus marts.trips_per_route_day
die Anzahl Zeilen, die Anzahl Linien, das kleinste und grösste service_date und die Summe
von n_trips.
```

Befehle:

```bash
cp -r referenz/transform/. transform/
gcloud iam service-accounts create transform-sa --display-name="Transform-Job dbt"
gcloud projects add-iam-policy-binding daeng-KÜRZEL-XXXX \
  --member="serviceAccount:transform-sa@daeng-KÜRZEL-XXXX.iam.gserviceaccount.com" \
  --role="roles/bigquery.dataEditor"
gcloud projects add-iam-policy-binding daeng-KÜRZEL-XXXX \
  --member="serviceAccount:transform-sa@daeng-KÜRZEL-XXXX.iam.gserviceaccount.com" \
  --role="roles/bigquery.jobUser"
gcloud run jobs deploy transform-gtfs --source transform --region europe-west6 \
  --service-account=transform-sa@daeng-KÜRZEL-XXXX.iam.gserviceaccount.com \
  --memory=1Gi --cpu=1 --task-timeout=20m --max-retries=0 \
  --set-env-vars DBT_PROJECT=daeng-KÜRZEL-XXXX
gcloud run jobs execute transform-gtfs --region europe-west6 --wait
bq query --use_legacy_sql=false \
  'SELECT COUNT(*) AS zeilen, COUNT(DISTINCT route_id) AS linien,
          MIN(service_date) AS von, MAX(service_date) AS bis, SUM(n_trips) AS fahrten
   FROM marts.trips_per_route_day'
```

Das Log endet mit der Zusammenfassung von dbt, `Done. PASS=22 ... TOTAL=22`, ohne `ERROR`
und ohne `FAIL`. Der Mart hat rund 50 Linien mal 14 Tage, also um 370 Zeilen, und rund
60 000 Fahrten, die genauen Zahlen hängen von der Version ab.

Checkpoint: Execution grün, drei neue Datasets `staging`, `intermediate`, `marts`.

---

## 6. Der Workflow

`pipeline/workflow.yaml` verbindet die drei Teile: Ingest, Scan, und nur wenn der Scan
besteht, die Transformation. Das ist die Qualitätsschranke. Neun Minuten, davon sechs für
den Lauf.

```text
Lege einen Service-Account workflow-sa an und warte, bis describe ihn zeigt. Rechte: Cloud
Run Invoker auf den Jobs ingest-gtfs und transform-gtfs, Cloud Run Viewer auf dem Projekt,
Dataplex DataScan Editor auf dem Scan trips-quality (per get-iam-policy, Datei ergänzen,
set-iam-policy mit etag), Logs Writer auf dem Projekt. Deploye dann pipeline/workflow.yaml
als Workflow gtfs-pipeline in europe-west6 mit workflow-sa und call-log-level
log-all-calls. Warte danach zwei Minuten (sleep 120), die Rollen brauchen so lange, bis
sie überall gelten. Starte den Workflow dann einmal und warte auf das Ende, das dauert
etwa sechs Minuten. Zeige mir das Ergebnis.
```

Befehle:

```bash
gcloud iam service-accounts create workflow-sa --display-name="Workflow gtfs-pipeline"
gcloud run jobs add-iam-policy-binding ingest-gtfs --region=europe-west6 \
  --member="serviceAccount:workflow-sa@daeng-KÜRZEL-XXXX.iam.gserviceaccount.com" \
  --role="roles/run.invoker"
gcloud run jobs add-iam-policy-binding transform-gtfs --region=europe-west6 \
  --member="serviceAccount:workflow-sa@daeng-KÜRZEL-XXXX.iam.gserviceaccount.com" \
  --role="roles/run.invoker"
gcloud projects add-iam-policy-binding daeng-KÜRZEL-XXXX \
  --member="serviceAccount:workflow-sa@daeng-KÜRZEL-XXXX.iam.gserviceaccount.com" \
  --role="roles/run.viewer"
gcloud dataplex datascans get-iam-policy trips-quality --location=europe-west6 \
  --format=json > /tmp/scan-policy.json
# Datei: workflow-sa mit roles/dataplex.dataScanEditor ergänzen, etag behalten
gcloud dataplex datascans set-iam-policy trips-quality /tmp/scan-policy.json \
  --location=europe-west6
gcloud projects add-iam-policy-binding daeng-KÜRZEL-XXXX \
  --member="serviceAccount:workflow-sa@daeng-KÜRZEL-XXXX.iam.gserviceaccount.com" \
  --role="roles/logging.logWriter"
gcloud workflows deploy gtfs-pipeline --source=pipeline/workflow.yaml \
  --location=europe-west6 \
  --service-account=workflow-sa@daeng-KÜRZEL-XXXX.iam.gserviceaccount.com \
  --call-log-level=log-all-calls
sleep 120
gcloud workflows run gtfs-pipeline --location=europe-west6
```

Die zwei Minuten sind kein Schmuck: Startet der Workflow früher, scheitert er in
`run_ingest` mit 403, weil `workflow-sa` die Rolle auf dem Job noch nicht überall hat.
Passiert das trotzdem, nochmals starten, sonst nichts.

Das Ergebnis ist ein kleines Dict mit der Ingest-Execution, dem Scan-Job, `passed: true`
und der Transform-Execution.

Checkpoint: Execution `SUCCEEDED`, `passed: true`.

---

## 7. Zeitplan und Alarm

Der Scheduler startet den Workflow Montag und Donnerstag um 11:30, nachdem der Publisher am
Vormittag veröffentlicht hat. Der Alarm schickt eine E-Mail, wenn ein Job oder der Workflow
scheitert. Lektion 4 verlässt sich auf beides. Drei Minuten, plus fünf für die E-Mail.

Prompt 1:

```text
Lege einen Service-Account scheduler-sa an, warte, bis describe ihn zeigt, und gib ihm die
Rolle Workflows Invoker auf dem Projekt. Lege einen Scheduler-Job gtfs-pipeline-schedule in
europe-west6 an, Montag und Donnerstag 11:30 Europe/Zurich, der über die
Workflow-Executions-API eine Execution von gtfs-pipeline startet, OAuth mit scheduler-sa.
Zeige mir den Scheduler-Job.
```

Prompt 2:

```text
Lege einen E-Mail-Benachrichtigungskanal für Monitoring an, Adresse ist die meines aktiven
gcloud-Kontos. Setze seine ID in einer Kopie von pipeline/alert-policy.yaml für CHANNEL_ID
ein, nicht in der Datei im Repo, und lege die Richtlinie daraus an. Starte dann ingest-gtfs
einmal mit SOURCE_URL=https://example.invalid/gtfs.zip, nur für diese Execution, und
warte. Erwartung: Die Execution scheitert innert Sekunden, das löst den Alarm aus.
```

Befehle:

```bash
gcloud iam service-accounts create scheduler-sa --display-name="Scheduler"
gcloud projects add-iam-policy-binding daeng-KÜRZEL-XXXX \
  --member="serviceAccount:scheduler-sa@daeng-KÜRZEL-XXXX.iam.gserviceaccount.com" \
  --role="roles/workflows.invoker"
gcloud scheduler jobs create http gtfs-pipeline-schedule --location=europe-west6 \
  --schedule="30 11 * * 1,4" --time-zone="Europe/Zurich" \
  --uri="https://workflowexecutions.googleapis.com/v1/projects/daeng-KÜRZEL-XXXX/locations/europe-west6/workflows/gtfs-pipeline/executions" \
  --http-method=POST \
  --oauth-service-account-email="scheduler-sa@daeng-KÜRZEL-XXXX.iam.gserviceaccount.com"
gcloud beta monitoring channels create --display-name="E-Mail Kurs" \
  --type=email --channel-labels=email_address=KÜRZEL@zhaw.ch
gcloud alpha monitoring policies create --policy-from-file=/tmp/alert-policy.yaml
gcloud run jobs execute ingest-gtfs --region europe-west6 --wait \
  --update-env-vars SOURCE_URL=https://example.invalid/gtfs.zip
```

Die Execution endet nach etwa 15 Sekunden mit `Failed to resolve 'example.invalid'`. Fünf
Minuten später kommt eine E-Mail "gtfs-pipeline fehlgeschlagen" an deine ZHAW-Adresse, und
ein paar Minuten danach schliesst Monitoring den Vorfall von selbst, das ist so gewollt
(Lektion 2, Schritt 7 erklärt, warum). Der gescheiterte Lauf hat nichts verändert, der Job
scheitert, bevor er etwas schreibt.

Checkpoint: Die E-Mail ist da. Du musst nicht auf sie warten, mach mit Schritt 8 weiter.

---

## 8. Prüfen

Dieser Prompt ändert nichts, er liest nur:

```text
Prüfe, ob mein Projekt den Stand nach Lektion 2 hat. Nur lesende Befehle. Gib am Ende eine
Tabelle mit den Spalten Prüfung, Ergebnis (PASS/FAIL) und Detail aus, bei jedem FAIL den
Befehl, der es beheben würde, ohne ihn auszuführen.

1. gcloud config get-value project ist ein Projekt daeng-*, es existiert, billingEnabled
   ist true, das Rechnungskonto hat "Education" im Namen
2. Bucket <projekt-id>-raw existiert, darin raw/gtfs/ mit zwei Ordnern version=*
3. Dataset raw hat acht Tabellen, trips hat zwei Partitionen mit je über einer Million Zeilen
4. Cloud-Run-Jobs ingest-gtfs (ingest-sa) und transform-gtfs (transform-sa) existieren, die
   letzte Execution von transform-gtfs ist erfolgreich
5. Dataplex-Scan trips-quality existiert, der letzte Scan-Job hat bestanden
6. Datasets staging, intermediate, marts existieren, marts.trips_per_route_day hat Zeilen
7. Workflow gtfs-pipeline existiert mit workflow-sa, die letzte Execution ist SUCCEEDED
8. Scheduler-Job gtfs-pipeline-schedule existiert, aktiviert, Ziel ist der Workflow
9. Eine Monitoring-Richtlinie mit "gtfs-pipeline" im Namen existiert, mit einem E-Mail-Kanal
10. checks/trips_quality.yaml enthält meine Projekt-ID und nicht daeng-pect-olw5
11. git status: transform/ ist gefüllt (dbt_project.yml existiert), sonst nichts
    verändert ausser checks/trips_quality.yaml und transform/

Letzte Zeile: READY oder NOT READY, mit der Anzahl FAILs.
```

Steht am Ende READY, bist du dort, wo Lektion 3 und 4 anfangen. Steht NOT READY, führe die
vorgeschlagenen Befehle aus oder melde dich mit der Tabelle.

---

## Was du übersprungen hast

Die Pipeline läuft, aber du hast die Erklärungen nicht gelesen, die Lektion 1 und 2 um
jeden Schritt herum geben. Das sind die sechs, die in Lektion 3 und 4 vorausgesetzt werden,
je fünf Minuten:

- Warum die Rohdaten unverändert im Bucket bleiben und jede Version eine eigene Partition
  ist, die ein zweiter Lauf ersetzt: [Lektion 1, Schritt 2](LEKTION-1.md#2-den-job-lesen).
- Warum jeder Job eine eigene Identität mit genau den nötigen Rechten hat:
  [Lektion 1, Schritt 3](LEKTION-1.md#3-identitäten).
- Was die fünf Regeln prüfen und warum zwei davon pro Version:
  [Lektion 1, Schritt 8](LEKTION-1.md#8-qualität-prüfen).
- Die drei Stufen Staging, Intermediate, Marts, und was dbt dabei tut:
  [Lektion 2, Schritt 2](LEKTION-2.md#2-die-transformation-erzeugen).
- Was in `check_gate` passiert und warum der Mart die letzte gute Version behält:
  [Lektion 2, Schritt 5](LEKTION-2.md#5-der-workflow).
- Warum Monitoring der Rauchmelder ist und nicht das Ticket:
  [Lektion 2, Schritt 7](LEKTION-2.md#7-der-alarm).

Und [SPEC-IM-TEAM.md](SPEC-IM-TEAM.md), wie aus einem Prompt im Team eine Spezifikation wird.

Weiter mit [Lektion 3](LEKTION-3.md) oder [Lektion 4](LEKTION-4.md). Lektion 4 braucht
Lektion 3 nicht.

---

## Wenn etwas schiefgeht

- **"Reauthentication required" oder "token expired":** Im Terminal `gcloud auth login` und
  `gcloud auth application-default login`, dann den Prompt wiederholen.
- **Claude Code sagt, ein Befehl sei gesperrt, und nennt den Auto-Modus:** Lies den Befehl,
  vergleiche ihn mit der Liste, und führ ihn mit der `!`-Zeile aus, die Claude Code anbietet.
- **Schritt 1: Claude Code stoppt beim Rechnungskonto oder beim Budget:** Den gezeigten
  Befehl selbst im Terminal ausführen, dann Claude Code sagen, es soll mit dem nächsten
  Punkt weitermachen.
- **Schritt 1: das Budget scheitert mit `USER_PROJECT_DENIED`:** Die Budget-API ist eben
  erst eingeschaltet und gilt noch nicht. Drei Minuten warten, denselben Befehl nochmals.
- **Schritt 1: gcloud fragt, ob es eine API einschalten soll (`Would you like to enable
  and retry?`):** `N`. Jede API, die der Kurs braucht, steht in Punkt 4, alles andere
  bleibt aus.
- **Schritt 2: `gcloud storage` stürzt mit einem Python-Fehler ab:** Alte gcloud-Version mit
  neuem Python. `gcloud components update`, Terminal neu öffnen.
- **Schritt 2: der Build scheitert mit "permission denied" auf Artifact Registry oder Cloud
  Build:** Das Compute-Standardkonto hat Cloud Run Builder noch nicht, oder die Rolle gilt
  noch nicht. Eine Minute warten, Deploy nochmals.
- **Schritt 4: `datascans create` meldet, das Dataset `checks` oder der Service Agent fehle:**
  Punkt 8 aus Schritt 1 nachholen (`gcloud beta services identity create
  --service=dataplex.googleapis.com`), beziehungsweise `bq mk --location=europe-west6 checks`.
- **Schritt 5: dbt endet mit `ERROR` oder `FAIL`:** Das ist die Musterlösung, sie sollte
  laufen. Meist fehlt die zweite Version oder `DBT_PROJECT` ist falsch gesetzt. Log lesen,
  die Zeile mit dem Fehler im Chat nennen.
- **Schritt 6: `gcloud workflows deploy` scheitert mit einem Hinweis auf den Service Agent:**
  `gcloud beta services identity create --service=workflows.googleapis.com`, eine Minute
  warten, Deploy nochmals.
- **Schritt 6: die Execution scheitert in `run_ingest` mit 403:** `workflow-sa` fehlt Cloud
  Run Invoker auf dem Job, oder die Rolle gilt noch nicht. Zwei Minuten warten, nochmals
  starten.
- **Schritt 7: keine E-Mail nach zehn Minuten:** [Monitoring → Alerting](https://console.cloud.google.com/monitoring/alerting)
  zeigt, ob ein Vorfall da ist. Ist er da, fehlt der Kanal in der Richtlinie. Ist keiner da,
  ist die Richtlinie nicht angelegt, `gcloud alpha monitoring policies list` zeigt es.
- **Claude Code will etwas ausführen, das nicht in der Liste steht:** Nicht freigeben. Frag
  im Chat, warum.
