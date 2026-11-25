# Workflow garage-pipeline

Verkettet die beiden Cloud-Run-Jobs der Garage Keller. Spezifikation: `garage/SPEC-PIPELINE.md`, Teil 4.

```
{"version": "JJJJ-MM-TT"}  →  garage-ingest (VERSION überschrieben)  →  garage-transform (dbt build)  →  {version, ingest_execution, transform_execution}
```

- **Eingabe:** `{"version": "JJJJ-MM-TT"}`. Ohne gültige Version endet der Workflow sofort mit einer Meldung.
- **Schranke:** `garage-transform` startet nur, wenn `garage-ingest` gelungen ist. Der Ingest bricht ab, wenn Dateien fehlen, eine Kopfzeile nicht zu `garage/ingest-job/schema.json` passt oder eine Partition leer bleibt. Dann behalten die Marts die letzte gute Version.
- **Keine Wiederholungen, keine Parallelität:** Eine fehlerhafte Lieferung wird durch einen zweiten Versuch nicht besser, und dbt braucht das Ergebnis des Ingest.
- **Projekt und Region** kommen zur Laufzeit aus der Umgebung des Workflows, die Datei enthält keine IDs.
- **Identität:** `garage-pipeline-sa` mit `roles/run.jobsExecutorWithOverrides` auf beiden Jobs (Invoker reicht nicht, weil der Ingest mit überschriebener Umgebungsvariable startet), `roles/logging.logWriter` und `roles/run.viewer` auf dem Projekt.
  `run.viewer` ist eine bewusste Abweichung von der Spezifikation: `jobsExecutorWithOverrides` enthält nur `run.jobs.run`, `run.jobs.runWithOverrides` und `run.executions.cancel`. Um auf das Ende eines Jobs zu warten, fragt der Connector die Operation ab (`run.operations.get`), und die hängt am Projekt, nicht am Job. `run.viewer` gibt nur Leserechte.

Gestartet wird der Workflow normalerweise über `bash garage/neue-version.sh JJJJ-MM-TT`, von Hand mit:

```bash
gcloud workflows run garage-pipeline --location=europe-west6 --data='{"version": "2026-11-17"}'
```

## Warum kein Zeitplan

Eine neue Lieferung entsteht, wenn jemand die Listen der Garage von Hand abtippt und als Ordner
`garage/data/version=JJJJ-MM-TT/` committet. Das passiert unregelmässig. Ein Zeitplan hätte nichts
Neues zu laden und würde eine Automatik vortäuschen, die es nicht gibt. Der Auslöser ist deshalb
der Mensch, der die Lieferung committet und `neue-version.sh` startet.
