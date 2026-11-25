#!/usr/bin/env bash
# Bringt eine Lieferung aus Git in die Cloud und baut die Marts neu.
# Aufruf: bash garage/neue-version.sh JJJJ-MM-TT
# Spezifikation: garage/SPEC-PIPELINE.md, Teil 5.
set -euo pipefail

# --- a) Lieferung lokal prüfen ---------------------------------------------
# Alles, was hier scheitert, scheitert vor dem ersten Upload: im Bucket landet nur, was passt.
if [[ $# -ne 1 || ! "$1" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]] || ! date -d "$1" >/dev/null 2>&1; then
  echo "Aufruf: bash garage/neue-version.sh JJJJ-MM-TT (ein gültiges Datum)" >&2
  exit 1
fi
VERSION="$1"

# Pfade relativ zum Skript, damit es egal ist, aus welchem Ordner man es startet.
GARAGE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DATA_DIR="${GARAGE_DIR}/data/version=${VERSION}"
SCHEMA_JSON="${GARAGE_DIR}/ingest-job/schema.json"

if [[ ! -d "${DATA_DIR}" ]]; then
  echo "Abbruch: Ordner ${DATA_DIR} fehlt." >&2
  exit 1
fi

# Dieselbe schema.json wie im Job, damit die Prüfung hier und in der Cloud nie auseinanderläuft.
# python3 statt jq, weil python3 ohnehin da ist.
python3 - "${SCHEMA_JSON}" "${DATA_DIR}" <<'EOF'
import csv, json, os, sys
schema = json.load(open(sys.argv[1], encoding="utf-8"))["dateien"]
ordner = sys.argv[2]
erwartet = {d["datei"] for d in schema}
gefunden = set(os.listdir(ordner))
if gefunden != erwartet:
    sys.exit(f"Abbruch: {ordner} enthält nicht genau die vier Dateien aus schema.json. "
             f"Fehlt: {sorted(erwartet - gefunden)}, zu viel: {sorted(gefunden - erwartet)}")
for d in schema:
    # utf-8-sig entfernt ein BOM, strip das Zeilenende: gleiche Regel wie im Job.
    with open(os.path.join(ordner, d["datei"]), encoding="utf-8-sig") as f:
        spalten = [s.strip() for s in next(csv.reader([f.readline().strip()]))]
    if spalten != d["spalten"]:
        sys.exit(f"Abbruch: Kopfzeile von {d['datei']} weicht von schema.json ab. "
                 f"Erwartet: {d['spalten']}, gefunden: {spalten}")
EOF
mapfile -t DATEIEN < <(python3 -c 'import json,sys; [print(d["datei"]) for d in json.load(open(sys.argv[1]))["dateien"]]' "${SCHEMA_JSON}")
echo "Lieferung ${DATA_DIR#"${GARAGE_DIR}/"}: ${#DATEIEN[@]} Dateien, Schema ok"

# --- b) Git ist die Quelle ----------------------------------------------------
# Was in der Cloud liegt, soll sich auf einen Commit zurückführen lassen.
if [[ -n "$(git -C "${GARAGE_DIR}" status --porcelain -- "${DATA_DIR}")" ]]; then
  echo "Abbruch: ${DATA_DIR} hat uncommittete Änderungen. Zuerst committen:" >&2
  echo "  git add \"${DATA_DIR}\" && git commit -m \"Lieferung ${VERSION}\"" >&2
  exit 1
fi
if [[ "$(git -C "${GARAGE_DIR}" ls-files -- "${DATA_DIR}" | wc -l)" -ne ${#DATEIEN[@]} ]]; then
  echo "Abbruch: Nicht alle Dateien in ${DATA_DIR} sind in Git (ignoriert?). Zuerst committen." >&2
  exit 1
fi
# Nur eine Warnung: der Commit existiert lokal, er ist bloss noch nicht geteilt.
VORAUS="$(git -C "${GARAGE_DIR}" rev-list --count '@{u}..HEAD' 2>/dev/null || echo 0)"
if [[ "${VORAUS}" -gt 0 ]]; then
  echo "Warnung: Branch ist ${VORAUS} Commit(s) vor dem Remote. Denk ans git push."
fi

# Projekt aus der gcloud-Konfiguration, damit nirgends eine Projekt-ID fest im Code steht.
PROJEKT="$(gcloud config get-value project 2>/dev/null || true)"
if [[ -z "${PROJEKT}" || "${PROJEKT}" == "(unset)" ]]; then
  echo "Abbruch: kein Standardprojekt gesetzt (gcloud config get-value project)." >&2
  exit 1
fi
ZIEL="gs://${PROJEKT}-raw/garage/version=${VERSION}"
REGION="europe-west6"

# --- c) Versionen sind unveränderlich --------------------------------------
# Eine Version, die einmal geladen ist, darf sich nicht still ändern, sonst wäre ein Mart mit
# derselben datenversion nicht mehr reproduzierbar. Gleich: nichts tun. Verschieden: abbrechen.
FEHLEND=()
for f in "${DATEIEN[@]}"; do
  LOKAL="$(gcloud storage hash "${DATA_DIR}/${f}" --skip-crc32c --format='value(md5_hash)')"
  if CLOUD="$(gcloud storage objects describe "${ZIEL}/${f}" --format='value(md5_hash)' 2>/dev/null)"; then
    if [[ "${LOKAL}" != "${CLOUD}" ]]; then
      echo "Abbruch: ${ZIEL}/${f} existiert schon und unterscheidet sich von der Datei in Git." >&2
      echo "Versionen sind unveränderlich: lege eine neue Version mit neuem Datum an." >&2
      exit 1
    fi
  else
    FEHLEND+=("${f}")
  fi
done
if [[ ${#FEHLEND[@]} -eq 0 ]]; then
  echo "Bucket: ${ZIEL}/ ist schon da, alle Prüfsummen gleich, nichts hochgeladen"
else
  for f in "${FEHLEND[@]}"; do
    gcloud storage cp "${DATA_DIR}/${f}" "${ZIEL}/${f}"
  done
  echo "Bucket: ${#FEHLEND[@]} Datei(en) nach ${ZIEL}/ hochgeladen"
fi

# --- d) Workflow starten und warten ----------------------------------------
echo "Starte Workflow garage-pipeline mit version=${VERSION} (Ingest, dann Transformation, einige Minuten)"
ERGEBNIS="$(gcloud workflows run garage-pipeline --location="${REGION}" \
  --data="{\"version\": \"${VERSION}\"}" --format=json)"
# gcloud workflows run endet auch bei einem gescheiterten Workflow mit 0, deshalb den Zustand lesen.
ZUSTAND="$(python3 -c 'import json,sys; print(json.load(sys.stdin)["state"])' <<<"${ERGEBNIS}")"
if [[ "${ZUSTAND}" != "SUCCEEDED" ]]; then
  echo "Fehler: Workflow endete mit ${ZUSTAND}. Die Marts behalten die letzte gute Version." >&2
  python3 -c 'import json,sys; e=json.load(sys.stdin); print(e["name"]); print(e.get("error",{}).get("payload",""))' <<<"${ERGEBNIS}" >&2
  exit 1
fi
python3 -c 'import json,sys; print("Workflow ok:", json.load(sys.stdin)["result"])' <<<"${ERGEBNIS}"

# --- e) Ergebnis zeigen ------------------------------------------------------
# Die Antwort an den Inhaber, damit man sofort sieht, welche Version die Marts jetzt zeigen.
bq query --project_id="${PROJEKT}" --location="${REGION}" --use_legacy_sql=false --format=pretty \
  "SELECT iso_woche, n_anfragen, mittlere_wartezeit, datenversion
   FROM \`${PROJEKT}.garage_marts.mart_wartezeit_woche\`
   ORDER BY iso_jahr, iso_woche" 2>/dev/null
