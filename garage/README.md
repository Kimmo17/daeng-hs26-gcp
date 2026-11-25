# Garage Keller: Data Product MVP auf Google Cloud

Projektordner von Team Tuner im Kurs-Repo `daeng-hs26-gcp`. Er baut für die Garage Keller einen
minimalen Datenfluss von den Rohdaten bis zur Antwort für den Inhaber:

- **IR-03:** Wie viele Arbeitstage wartet eine Anfrage bis zum ersten angebotenen Termin, je Woche, mit Fallzahl?
- **IR-01 (eingeschränkt):** Wie viele Termine liegen je Arbeitstag vor? Eine Planungsquote ist nicht möglich, weil der Aufwand fehlt (Data Gap Map E-02).
- **Kontrolle G-02:** Wird die Anfrageliste lückenlos geführt? Verhältnis Einträge zu angenommenen Anrufen je Tag.

**Alle Daten sind SYNTHETISCH** (Woche 7 und 8). Die Pipeline beweist, dass Ablauf, Modell und Tests
funktionieren. Über die Garage sagt sie nichts. Jede Mart-Zeile trägt die Spalte `datenstatus = 'synthetisch'`.

## Ablauf

```
data/version=2026-11-17/*.csv   →  gs://<projekt>-raw/garage/version=2026-11-17/   (Storage)
                                →  BigQuery garage_raw, 4 Tabellen, alles STRING     (Ingestion)
                                →  dbt: garage_staging → garage_intermediate → garage_marts  (Transformation + Tests)
                                →  3 Marts für den Inhaber                           (Serving)
```

## Neue Lieferung einspielen

1. Ordner `garage/data/version=JJJJ-MM-TT/` mit den vier CSV anlegen (gleiche Dateinamen und Kopfzeilen wie bisher, siehe `ingest-job/schema.json`).
2. Committen: `git add garage/data/version=JJJJ-MM-TT && git commit -m "Lieferung JJJJ-MM-TT"`.
3. `bash garage/neue-version.sh JJJJ-MM-TT` prüft die Lieferung, lädt sie in den Bucket, startet den Workflow `garage-pipeline` und zeigt danach `mart_wartezeit_woche`.

Eine Version ist unveränderlich: Liegt sie schon im Bucket und unterscheidet sich, bricht das Skript ab. Für eine Korrektur gibt es eine neue Version mit neuem Datum. Details in `pipeline/README.md`.

## Dateien

| Datei | Inhalt |
|---|---|
| `data/version=2026-11-17/` | DS-01 Terminbuch, DS-02 Reifenhotel, DATA-01 Anfragen, DATA-02 Anrufe (CSV) |
| `SPEC-INGEST.md` | Spezifikation für das Laden nach Storage und BigQuery |
| `SPEC-TRANSFORM.md` | Spezifikation für das dbt-Projekt mit Star-Schema, Tests und Marts |
| `PROMPTS.md` | Die Prompts für Claude Code, Schritt für Schritt |
| `LIFECYCLE.md` | Arbeitsauftrag 19 (Lifecycle Mapping) und Ergebnis des Workshops |

Bezug zu den früheren Abgaben: IR-IDs aus dem IR Catalogue (W6), Gap-IDs aus der Data Gap Map (W7),
SRC- und DATA-IDs aus dem Data Sourcing Plan (W8).
