dbt-Projekt `garage_transform`: baut aus `garage_raw` ein Star-Schema und drei Marts für die Garage Keller.
Alle Daten sind synthetisch; jede Mart-Zeile trägt `datenstatus = 'synthetisch'` (Variable in `dbt_project.yml`).
Schichten: `garage_staging` (typisiert) → `garage_intermediate` (dim_*, fct_*, Seeds) → `garage_marts`.
Marts: `mart_wartezeit_woche` (IR-03), `mart_termine_tag` (IR-01, nur Terminzahl), `mart_erfassung_tag` (G-02).
Harte Tests stoppen den Build; Datenqualitäts-Tests (severity warn) melden bekannte Befunde nur.
Einmalig: `python3 -m venv .venv && .venv/bin/pip install -r requirements.txt` (im Ordner `garage/transform`).
Start im Ordner `garage/transform`: `export DBT_PROJECT=$(gcloud config get-value project)`.
Dann: `.venv/bin/dbt seed --profiles-dir .` und `.venv/bin/dbt build --profiles-dir .`
Anmeldung über Application Default Credentials (`gcloud auth application-default login`), kein Schlüssel.
Spezifikation: `garage/SPEC-TRANSFORM.md`; Variablen: datenstatus, mindestfallzahl, schwelle_erfassung.
