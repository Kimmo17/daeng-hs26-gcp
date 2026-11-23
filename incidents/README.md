# incidents: drei Vorfälle zum Nachstellen

Drei Dinge, die im Betrieb einer Pipeline passieren, so vorbereitet, dass du sie in deinem Projekt
auslösen, vom Agenten untersuchen lassen und wieder rückgängig machen kannst (Lektion 4). Nichts
in diesem Ordner ist Teil der Pipeline.

Jeder Vorfall lässt `gtfs-pipeline` scheitern, der Alarm aus Lektion 2 schickt eine E-Mail, und
der Agent bekommt die fehlgeschlagene Execution. Der Agent kennt diesen Ordner nicht.

## B: Jemand hat die Regel geändert

Die Schwelle der Regel `min-one-million-rows-per-version` steigt auf 3 Millionen. Die Lieferung hat
2.6 Millionen Zeilen, der Scan scheitert, die Qualitätsschranke schliesst.

```bash
sed 's/< 1000000/< 3000000/' checks/trips_quality.yaml > /tmp/trips_quality_3m.yaml
gcloud dataplex datascans update data-quality trips-quality --location=europe-west6 \
  --data-quality-spec-file=/tmp/trips_quality_3m.yaml
gcloud workflows run gtfs-pipeline --location=europe-west6 --async
```

Rückgängig: dieselbe Zeile mit `checks/trips_quality.yaml` aus dem Repo (deiner Kopie mit deiner
Projekt-ID).

## C: Jemand hat Code deployt

`ingest-append.patch` ändert eine Zeile in `ingest/main.py`: `WRITE_TRUNCATE` wird `WRITE_APPEND`.
Der nächste Lauf lädt die Version, die schon in `raw.trips` liegt, und hängt sie an sich selbst
an. Jede `trip_id` ist doppelt, die Regel `trip-id-unique-per-version` scheitert. Nur wenn der
Publisher seit dem letzten Lauf eine neue Version veröffentlicht hat, geht der erste Lauf durch,
und erst der zweite scheitert.

```bash
git apply incidents/ingest-append.patch
gcloud run jobs deploy ingest-gtfs --source ingest --region europe-west6 \
  --service-account=ingest-sa@PROJEKT-ID.iam.gserviceaccount.com
gcloud workflows run gtfs-pipeline --location=europe-west6 --async
```

Rückgängig: `git checkout ingest/main.py`, denselben Deploy nochmals, den Workflow einmal laufen
lassen. `WRITE_TRUNCATE` ersetzt die verdoppelte Partition von selbst.

## D: Jemand hat eine Rolle entfernt

`workflow-sa` verliert Cloud Run Invoker auf `ingest-gtfs`. Der Workflow scheitert in Sekunden mit
403, bevor irgendetwas geladen wird.

```bash
gcloud run jobs remove-iam-policy-binding ingest-gtfs --region=europe-west6 \
  --member="serviceAccount:workflow-sa@PROJEKT-ID.iam.gserviceaccount.com" \
  --role="roles/run.invoker"
# zwei Minuten warten, so lange braucht der Entzug, bis er überall gilt
gcloud workflows run gtfs-pipeline --location=europe-west6 --async
```

Rückgängig: `add-iam-policy-binding` mit denselben Argumenten.

## Übung ohne Anleitung: Jemand hat Daten gelöscht

Ein `DELETE`, das aus der neuesten Partition von `raw.trips` so viele Zeilen entfernt, dass
weniger als eine Million bleiben (aber nicht null, eine leere Partition zählt der Scan nicht),
lässt dieselbe Regel wie in B scheitern, mit einer anderen Ursache. Der Agent hat alles, was er
dafür braucht: Zeilen und `last_modified_time` pro Partition, und den DML-Job in `JOBS_BY_PROJECT`
mit dem Konto, das ihn ausgeführt hat. Die neueste Partition, weil der nächste Lauf sie ersetzt:
die richtige Massnahme ist dann, den Workflow einmal laufen zu lassen, nichts weiter. Eine
ältere Partition käme nicht zurück, der Publisher liefert nur die aktuelle Version. Das ist der
Grund, warum die Übung keine Anleitung hat und warum Löschen ein Mensch tut.
