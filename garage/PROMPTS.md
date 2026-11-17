# Prompts für Claude Code

Starte Claude Code im Repo-Ordner `daeng-hs26-gcp` (nicht in `garage/`), damit die Regeln aus `CLAUDE.md` gelten.
Füge die Prompts einzeln ein. Lies jeden Befehl, bevor du ihn freigibst. Kosten: Die Daten sind
kleiner als ein Megabyte, Storage und Abfragen kosten praktisch nichts.

## Prompt 1: Ingest bauen und ausführen

```text
Lies garage/README.md und garage/SPEC-INGEST.md. Erzeuge garage/ingest/load.sh und garage/ingest/README.md genau nach der Spezifikation.
Zeige mir das Skript, bevor du es ausführst, und erkläre jeden gcloud- und bq-Befehl darin in einem Satz.
Dann führe es mit dem Argument 2026-11-17 aus und prüfe die Akzeptanzkriterien aus der Spezifikation, auch den zweiten Lauf.
Nicht tun: nichts ausserhalb von garage/ ändern, keinen Bucket anlegen, kein Autodetect.
Fertig ist es, wenn die vier Zeilenzahlen stimmen und ein zweiter Lauf dieselben Zahlen ergibt. Gib sie mir als Tabelle.
```

## Prompt 2: Python-Umgebung für dbt

```text
Lege unter garage/transform/.venv eine Python-Umgebung an und installiere dbt-core und dbt-bigquery (>=1.10,<2).
Falls python3-venv fehlt, sag mir den apt-Befehl und stoppe, ich führe ihn selbst aus.
Trage .venv in die .gitignore ein. Zeige mir am Ende dbt --version.
```

## Prompt 3: dbt-Projekt erzeugen

```text
Lies garage/SPEC-TRANSFORM.md. Als Muster für Aufbau, Profil und generate_schema_name darfst du referenz/transform/ lesen.
Erzeuge das dbt-Projekt unter garage/transform/ genau nach der Spezifikation. Führe noch nichts gegen BigQuery aus.
Zeige mir danach eine Liste aller erzeugten Dateien und für fct_anfrage und mart_wartezeit_woche das SQL.
Nicht tun: keine Packages, keine Views, kein incremental, keine Dateien ausserhalb von garage/.
```

## Prompt 4: Bauen und gegen die Akzeptanzkriterien prüfen

```text
Setze DBT_PROJECT auf die Ausgabe von gcloud config get-value project und starte in garage/transform mit der .venv:
dbt seed --profiles-dir . und danach dbt build --profiles-dir .
Wenn ein harter Test fehlschlägt: zeige die Meldung, erkläre sie und schlage einen Fix vor, ohne ihn auszuführen.
Wenn alles durchläuft: frage die drei Marts mit bq query ab und vergleiche jede Zahl mit den Akzeptanzkriterien in SPEC-TRANSFORM.md.
Gib mir eine Tabelle: Kriterium, Soll, Ist, PASS oder FAIL. Liste ausserdem alle Warnungen der Datenqualitäts-Tests mit Anzahl Zeilen.
```

## Prompt 5: Dokumentation für die Abgabe

```text
Erzeuge garage/DOKUMENTATION.md mit: (1) Datenmodell als Mermaid-Diagramm (Fakten, Dimensionen, Schlüssel),
(2) Transformationslogik je Modell in einem Satz, (3) Metrik-Definitionen von mart_wartezeit_woche, mart_termine_tag und mart_erfassung_tag,
(4) Tests: harte Tests und Datenqualitäts-Tests mit dem Ergebnis des letzten Laufs, (5) bekannte Grenzen: synthetische Daten,
keine Feiertage, keine Planungsquote, nicht notierte Anfragen sind unsichtbar.
Nimm die Zahlen aus dem letzten Lauf, nicht aus der Spezifikation.
```

## Danach

```bash
git add garage && git commit -m "Garage Keller: MVP-Pipeline"
```

Prüfe in der Cloud Console unter **BigQuery**: die Datasets `garage_raw`, `garage_staging`, `garage_intermediate`
und `garage_marts`. Unter **Abrechnung → Budgets** sollte praktisch kein Verbrauch zu sehen sein.
