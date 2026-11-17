# Arbeitsauftrag 19: Lifecycle Mapping und Ergebnis des Workshops

Datenfluss: **Terminanfragen bis zur Wartezeit je Woche (G-02, IR-03)**, ergänzt um Terminbuch (IR-01).
Alle Datenbestände sind synthetisch. Zuordnungen mit «belegt» verweisen auf ein Artefakt, das existiert.

## Mapping

| Phase | Artefakt in unserem Projekt | Beleg | Lücke / unklare Zuständigkeit |
|---|---|---|---|
| Generation | Anfrageliste neben dem Telefon (SRC-01), Anrufliste (SRC-02), Terminbuch (DI-01), Reifenhotel-Liste (DI-03) | Data Sourcing Plan W8; Dateninventar W7 | Nicht notierte Anfragen und verpasste Anrufe entstehen nie als Daten. Keine Pipeline kann sie rekonstruieren. Erfassung hängt an der Disziplin des Inhabers. |
| Storage | `data/version=2026-11-17/` im Repo; `gs://daeng-haurikim-9gjm-raw/garage/version=2026-11-17/` unverändert; BigQuery `daeng-haurikim-9gjm.garage_raw` | Bucket `gs://daeng-haurikim-9gjm-raw` (EUROPE-WEST6) mit 4 Dateien; Datasets `garage_raw`, `garage_staging`, `garage_intermediate`, `garage_marts` | Papierblätter beim Inhaber sind die eigentliche Rohquelle; Aufbewahrung und Vernichtung nach Projektende nur im Plan geregelt. |
| Ingestion | `garage/ingest/load.sh`, Batch, manuell, `--replace`, Schema alles STRING | Zeilenzahlen 199 / 189 / 104 / 10, zweiter Lauf identisch | Abtippen der Papierliste ist ein manueller Schritt ohne Kontrolle; kein Zeitplan; frühere Versionen in BigQuery werden überschrieben. |
| Transformation | dbt: Staging (Typen, Normierung, Plausibilität) → Star-Schema (`fct_anfrage`, `fct_termin`, `dim_datum`, `dim_kanal`, `dim_auftragsart`) → Marts | `dbt build` vom 17.11.2026: PASS=31, WARN=5, ERROR=0; 17 harte Tests PASS, 5 Datenqualitäts-Warnungen | Codierregel Auftragsart und Arbeitstage ohne Feiertage sind Team-Annahmen; Schwellen nicht mit dem Inhaber vereinbart. |
| Serving | `mart_wartezeit_woche` (IR-03), `mart_termine_tag` (IR-01, eingeschränkt), `mart_erfassung_tag` (Kontrolle G-02) | Export `ergebnisse/*.csv`: 2 / 20 / 10 Zeilen, alle Akzeptanzkriterien PASS (`ABNAHME.md`) | Der Inhaber arbeitet nicht in BigQuery. Wie die Zahlen bei ihm ankommen (Ausdruck, Tabelle), ist offen. |

**Undercurrents:** Security: nur ADC, kein Schlüssel; keine Personendaten, Kunden pseudonymisiert (NFR-04). Data Management: Label und Spalte `datenstatus = synthetisch`. DataOps: dbt-Tests, Qualitätsbefunde als Warnung. Software Engineering: alles versioniert im Repo.

## Workshop: Rollenperspektiven

| Rolle | Frage | Befund |
|---|---|---|
| Engineering | Läuft der Datenfluss von der Quelle bis zum Datensatz? | Ja, wiederholbar, mit Tests. Die Zahlen stimmen mit den Excel-Abgaben überein. |
| Science | Welche Analyse ist möglich, welche Annahmen braucht sie? | Wartezeit je Woche mit Fallzahl ist berechenbar. Annahmen: notiert = angefragt; Anteil Anfragen an Anrufen konstant; keine Feiertage. Die Wartezeit enthält den Kundenwunsch, deshalb zusätzlich die Verschiebung gegenüber dem Wunschtag. |
| Business | Welche Entscheidung soll der Datensatz unterstützen? | D-04: Terminregel und Schwelle beibehalten, anpassen oder verwerfen. Mit synthetischen Daten noch nicht entscheidbar. |

**Geprüfter Datenfluss:** DATA-01 → `garage_raw.anfragen` → `stg_anfragen` → `fct_anfrage` → `mart_wartezeit_woche`.

**Dokumentiertes Eignungsrisiko:** Technisch verfügbar ≠ analytisch valide. Die Pipeline zählt nur, was notiert wurde. An vollen Tagen wird am ehesten vergessen zu notieren, also wird die Wartezeit genau dann unterschätzt, wenn sie am längsten ist. `mart_erfassung_tag` macht das Risiko sichtbar, behebt es aber nicht.

**Drei priorisierte Verbesserungen:**
1. Echte Anfrageliste während der vierwöchigen Erhebung führen und die synthetischen Daten ersetzen (Generation; schliesst G-02 erst fachlich).
2. Versionierte Ingestion: jede Version als eigene Partition in `garage_raw` statt `--replace`, damit frühere Stände rekonstruierbar bleiben (Storage/Ingestion; vgl. Zeitlücke E-09).
3. Auftragsblatt DS-03 anbinden, damit aus der Terminzahl eine echte Planungsquote wird (Transformation; schliesst E-02 für IR-01).
