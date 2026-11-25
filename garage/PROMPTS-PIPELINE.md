# Prompts: Wiederholbarkeit (Woche 10/11)

Ziel: Eine neue Lieferung im Git-Ordner `garage/data/version=JJJJ-MM-TT/` mit einem Befehl in die Cloud
bringen und die Marts neu bauen. Spezifikation: `garage/SPEC-PIPELINE.md`.

Ablauf in WSL, im Repo-Ordner `daeng-hs26-gcp`:
```bash
git pull                     # euren Fork auf den neuesten Stand
unzip /mnt/c/Users/<DEIN-NAME>/Downloads/garage-wiederholbarkeit.zip   # fügt garage/SPEC-PIPELINE.md, diese Datei, Lieferung 2026-12-14 und das Erzeugungsskript hinzu
gcloud auth login
gcloud auth application-default login
claude
```
Dann die Prompts einzeln einfügen. Lies jeden Befehl, bevor du ihn freigibst.
Kosten: einige Minuten Cloud Build und kurze Job-Läufe, Rappenbeträge aus dem Guthaben.

## Prompt 0: Fork mit dem Kurs-Repo synchronisieren

```text
Mein Fork soll die Updates aus dem Kurs-Repo vp-82/daeng-hs26-gcp übernehmen, bevor wir weiterbauen.
Prüfe mit git remote -v, ob es ein Remote upstream gibt. Wenn nicht, lege es an: https://github.com/vp-82/daeng-hs26-gcp.git.
Dann: git fetch upstream, zeige mir mit git log --oneline HEAD..upstream/main, was neu ist, und führe git merge upstream/main aus.
Unser Ordner garage/ gibt es nur im Fork, Konflikte sind deshalb nicht zu erwarten. Gibt es trotzdem einen Konflikt: stoppe, zeige ihn mir und löse nichts selbst.
Danach committe die neuen Dateien aus dem ZIP (garage/SPEC-PIPELINE.md, garage/PROMPTS-PIPELINE.md, garage/data/version=2026-12-14/, garage/tools/) mit der Nachricht «Garage: Spezifikation Wiederholbarkeit und Lieferung 2026-12-14» und pushe nach origin.
Prüfe vorher, dass origin mein Fork ist und nicht vp-82/daeng-hs26-gcp.
Lies danach CLAUDE.md neu, die Regeln haben sich geändert.
Fertig ist es, wenn git status sauber ist und git log --oneline -3 den Merge und unseren Commit zeigt.
```

## Prompt 1: Ingest-Job bauen und deployen

```text
Lies garage/SPEC-PIPELINE.md, Teile 1 und 2. Als Muster für Job, Dockerfile, Identität, Artifact Registry und Cloud Build darfst du ingest/ lesen,
und ich verlange ausdrücklich, dass du docs/LEKTION-1.md Schritte 2 bis 5 liest.
Erzeuge garage/ingest-job/ nach der Spezifikation. Zeige mir main.py, bevor du baust.
Dann: Service-Account garage-ingest-sa mit genau den Rechten aus der Spezifikation, Image bauen (Cloud Build, Artifact Registry in europe-west6, ein Repository garage, falls es keines gibt), Job garage-ingest in europe-west6 anlegen.
Noch nicht ausführen. Erkläre jeden gcloud-Befehl in einem Satz.
Nicht tun: nichts in garage_raw ändern, keine weiteren Rechte, keine Dienste ausserhalb der Liste in CLAUDE.md.
Fertig ist es, wenn gcloud run jobs describe garage-ingest den Job mit garage-ingest-sa zeigt.
```

## Prompt 2: garage_raw auf Versionen umstellen und Version 1 laden

```text
Die vier Tabellen in garage_raw sind heute nicht partitioniert, weil load.sh sie mit --replace geladen hat. Der Job lädt aber in Partitionen.
Zeige mir die vier Befehle, um terminbuch, reifenhotel, anfragen und anrufe in garage_raw zu löschen, und warte auf meine ausdrückliche Bestätigung.
Die Rohdaten gehen dabei nicht verloren: Sie liegen unverändert im Bucket unter garage/version=2026-11-17/.
Nach meiner Bestätigung: Lösche die vier Tabellen und starte den Job mit
gcloud run jobs execute garage-ingest --region=europe-west6 --update-env-vars=VERSION=2026-11-17 --wait
Prüfe danach die Akzeptanzkriterien für 2026-11-17 auf der Ebene garage_raw (Zeilen pro Partition, ladeprotokoll) und gib sie mir als Tabelle.
Nicht tun: garage_staging, garage_intermediate und garage_marts nicht anfassen.
```

## Prompt 3: Transformation versionieren und als Job deployen

```text
Lies garage/SPEC-PIPELINE.md, Teil 3. Als Muster für das Makro und das Dockerfile verlange ich ausdrücklich, dass du referenz/transform/ liest (latest_version.sql und Dockerfile).
Ändere garage/transform/ nach der Spezifikation. Zeige mir das Makro neueste_version und ein Staging-Modell, bevor du etwas ausführst.
Teste zuerst lokal mit der .venv: DBT_PROJECT aus gcloud config get-value project, dann dbt build --profiles-dir .
Vergleiche die drei Marts mit garage/ABNAHME.md und zeige mir eine Tabelle Soll, Ist, PASS/FAIL. Erst wenn alles PASS ist:
Service-Account garage-transform-sa mit genau den Rechten aus der Spezifikation, Image bauen, Job garage-transform anlegen, einmal mit --wait ausführen.
Nicht tun: keine Packages, keine Logik der Marts ändern ausser der Spalte datenversion.
```

## Prompt 4: Workflow und der Befehl neue-version.sh

```text
Lies garage/SPEC-PIPELINE.md, Teile 4 bis 6. Als Muster darfst du pipeline/workflow.yaml lesen, und ich verlange ausdrücklich, dass du docs/LEKTION-2.md Schritt 5 liest.
Erzeuge garage/pipeline/workflow.yaml, garage/pipeline/README.md und garage/neue-version.sh nach der Spezifikation.
Service-Account garage-pipeline-sa mit genau den Rechten aus der Spezifikation, Workflow garage-pipeline in europe-west6 deployen.
Ergänze garage/README.md um einen kurzen Abschnitt «Neue Lieferung einspielen» mit den drei Schritten: Ordner anlegen, committen, bash garage/neue-version.sh JJJJ-MM-TT.
Teste dann den ganzen Weg mit bash garage/neue-version.sh 2026-11-17. Die Dateien liegen schon im Bucket und müssen als gleich erkannt werden.
Fertig ist es, wenn der Workflow gelingt und die Marts die Werte aus ABNAHME.md mit datenversion 2026-11-17 zeigen.
```

## Prompt 5: Eine neue Lieferung einspielen und die Wiederholbarkeit prüfen

```text
Spiele die neue Lieferung ein: bash garage/neue-version.sh 2026-12-14.
Prüfe danach alle Akzeptanzkriterien aus garage/SPEC-PIPELINE.md der Reihe nach: Lauf 2026-12-14, zweiter Lauf 2026-12-14, nochmals 2026-11-17, lokale Reproduktion mit --vars, danach garage-transform nochmals laufen lassen, und die beiden Negativtests.
Lösche die Testordner der Negativtests danach wieder, committe nichts davon.
Gib mir eine Tabelle: Kriterium, Soll, Ist, PASS oder FAIL. Wenn etwas FAIL ist: zeige die Ursache und schlage einen Fix vor, ohne ihn auszuführen.
```

## Prompt 6: Dokumentation und Commit

```text
Schreibe garage/WIEDERHOLBARKEIT.md: (1) Ablauf als Mermaid-Diagramm von Git über Bucket, garage-ingest, garage_raw mit Partitionen, garage-transform bis zu den Marts,
(2) wie man eine neue Lieferung einspielt, (3) die drei Eigenschaften mit Beleg aus Prompt 5: versioniert, idempotent, mit Schranke,
(4) Tabelle der Akzeptanzkriterien aus Prompt 5, (5) Grenzen: kein Zeitplan mit Begründung, Snapshot-Annahme, synthetische Daten.
Ergänze in garage/LIFECYCLE.md bei Storage und Ingestion je einen Satz, dass Verbesserung 2 (versionierte Ingestion) umgesetzt ist, und verweise auf WIEDERHOLBARKEIT.md.
Zeige mir git status. Committe nach meiner Bestätigung mit «Garage Keller: wiederholbare Pipeline» und pushe nach origin.
```
