#!/usr/bin/env bash
# Lädt eine Version der Garage-Keller-Rohdaten (synthetisch) nach Cloud Storage und BigQuery.
# Aufruf: bash garage/ingest/load.sh 2026-11-17
# Wiederholbar: Ein zweiter Lauf mit demselben Datum überschreibt Dateien und Tabellen,
# statt Duplikate zu erzeugen.
set -euo pipefail

# --- Argument prüfen -------------------------------------------------------
# Das Datum ist der einzige Parameter, damit eine spätere Lieferung
# (z. B. 2026-12-01) ohne Änderung am Skript geladen werden kann.
if [[ $# -ne 1 || ! "$1" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]; then
  echo "Aufruf: bash garage/ingest/load.sh JJJJ-MM-TT" >&2
  exit 1
fi
DATUM="$1"

# Pfade relativ zum Skript, damit es egal ist, aus welchem Ordner man es startet.
GARAGE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DATA_DIR="${GARAGE_DIR}/data/version=${DATUM}"

# Projekt aus der gcloud-Konfiguration, damit nirgends eine Projekt-ID fest im Code steht.
PROJEKT="$(gcloud config get-value project 2>/dev/null || true)"
if [[ -z "${PROJEKT}" || "${PROJEKT}" == "(unset)" ]]; then
  echo "Abbruch: kein Standardprojekt gesetzt (gcloud config get-value project)." >&2
  exit 1
fi
BUCKET="gs://${PROJEKT}-raw"
ZIEL="${BUCKET}/garage/version=${DATUM}/"
DATASET="garage_raw"
LOCATION="europe-west6"

# Zuordnung Datei -> Tabelle. Reihenfolge fest, damit die Ausgabe immer gleich aussieht.
DATEIEN=(ds01_terminbuch.csv ds02_reifenhotel.csv data01_anfragen.csv data02_anrufe.csv)
TABELLEN=(terminbuch reifenhotel anfragen anrufe)

# --- Schritt 1: Lieferung prüfen -------------------------------------------
# Lieber früh abbrechen als eine unvollständige oder fremde Lieferung halb zu laden.
if [[ ! -d "${DATA_DIR}" ]]; then
  echo "Abbruch: Ordner ${DATA_DIR} fehlt." >&2
  exit 1
fi
for f in "${DATEIEN[@]}"; do
  if [[ ! -f "${DATA_DIR}/${f}" ]]; then
    echo "Abbruch: ${f} fehlt in ${DATA_DIR}." >&2
    exit 1
  fi
done
ANZAHL="$(find "${DATA_DIR}" -mindepth 1 -maxdepth 1 | wc -l)"
if [[ "${ANZAHL}" -ne 4 ]]; then
  echo "Abbruch: ${DATA_DIR} enthält ${ANZAHL} Einträge statt genau 4." >&2
  exit 1
fi

# Den Bucket nur prüfen, nie anlegen: Er gehört zur Kurs-Infrastruktur.
if ! gcloud storage buckets describe "${BUCKET}" --project="${PROJEKT}" >/dev/null 2>&1; then
  echo "Abbruch: Bucket ${BUCKET} existiert nicht oder ist nicht lesbar. Er wird nicht angelegt." >&2
  exit 1
fi

# --- Schritt 2: Rohdaten unverändert in den Bucket -------------------------
# Unveränderte Kopie, damit man jede Version später exakt nachladen kann.
# Gleiche Dateinamen überschreiben sich beim zweiten Lauf, es entstehen keine Duplikate.
echo "Kopiere nach ${ZIEL}"
for f in "${DATEIEN[@]}"; do
  gcloud storage cp "${DATA_DIR}/${f}" "${ZIEL}" --project="${PROJEKT}"
done

# --- Schritt 3: Dataset anlegen, falls es fehlt ----------------------------
# bq mk würde bei einem vorhandenen Dataset scheitern, deshalb zuerst nachsehen.
if ! bq --project_id="${PROJEKT}" show --dataset "${PROJEKT}:${DATASET}" >/dev/null 2>&1; then
  bq --project_id="${PROJEKT}" mk --dataset --location="${LOCATION}" \
    --description="Rohdaten Garage Keller, synthetisch" "${PROJEKT}:${DATASET}"
fi

# --- Schritte 4 und 5: Laden mit Schema aus lauter STRING-Spalten ----------
# Alles STRING, damit ein Formatfehler erst in dbt sichtbar wird, statt beim Laden
# still zu verschwinden. Kein Autodetect: Das Schema kommt aus der Kopfzeile.
for i in "${!DATEIEN[@]}"; do
  f="${DATEIEN[$i]}"
  t="${TABELLEN[$i]}"
  # Kopfzeile lesen, Zeilenende und ein allfälliges BOM entfernen, jede Spalte als STRING.
  KOPF="$(head -n 1 "${DATA_DIR}/${f}" | tr -d '\r' | sed 's/^\xEF\xBB\xBF//')"
  SCHEMA="$(echo "${KOPF}" | awk -F',' '{for (i = 1; i <= NF; i++) printf "%s%s:STRING", (i > 1 ? "," : ""), $i}')"

  echo "Lade ${f} -> ${DATASET}.${t}"
  # --replace ersetzt den Tabelleninhalt, damit ein zweiter Lauf dieselbe Zeilenzahl ergibt.
  bq --project_id="${PROJEKT}" --location="${LOCATION}" load --replace \
    --source_format=CSV --skip_leading_rows=1 \
    "${PROJEKT}:${DATASET}.${t}" "${ZIEL}${f}" "${SCHEMA}"

  # Beschreibung und Label machen in jeder Abfrage klar, dass die Daten synthetisch sind.
  bq --project_id="${PROJEKT}" update \
    --description="SYNTHETISCH, version=${DATUM}" \
    --set_label=datenstatus:synthetisch \
    "${PROJEKT}:${DATASET}.${t}"
done

# --- Schritt 6: Zeilenzahlen ausgeben --------------------------------------
# Aus den Tabellen-Metadaten statt per Abfrage: kostet nichts und ist nach dem Laden aktuell.
echo
echo "Zeilenzahlen ${DATASET} (version=${DATUM}):"
for t in "${TABELLEN[@]}"; do
  N="$(bq --project_id="${PROJEKT}" show --format=json "${PROJEKT}:${DATASET}.${t}" \
       | python3 -c 'import json,sys; print(json.load(sys.stdin)["numRows"])')"
  printf "  %-12s %s\n" "${t}" "${N}"
done
