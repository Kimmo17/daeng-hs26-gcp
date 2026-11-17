# Abnahmeprotokoll Garage Keller (W9 und W10)

| | |
|---|---|
| Datum | 17.11.2026 |
| Team | Tuner |
| Projekt-ID | `daeng-haurikim-9gjm` (Region europe-west6) |
| dbt-Version | dbt-core 1.12.7, dbt-bigquery 1.12.4 |
| Lauf | `dbt build` vom 17.11.2026, 20:54, Log in `ergebnisse/dbt_build_log.txt` |
| Ergebnis des Laufs | PASS=31, WARN=5, ERROR=0, SKIP=0 (2 Seeds, 12 Modelle, 22 Tests) |
| Exporte | `ergebnisse/mart_wartezeit_woche.csv`, `mart_termine_tag.csv`, `mart_erfassung_tag.csv` |
| Datenstatus | **synthetisch**; die Zahlen prüfen den Ablauf, nicht die Garage |

Alle Ist-Werte stammen aus diesem Lauf und den daraus exportierten CSV-Dateien.

## Akzeptanzkriterien Ingest (SPEC-INGEST.md)

| Kriterium | Soll | Ist | Ergebnis |
|---|---|---|---|
| `garage_raw.terminbuch` Zeilen | 199 | 199 | PASS |
| `garage_raw.reifenhotel` Zeilen | 189 | 189 | PASS |
| `garage_raw.anfragen` Zeilen | 104 | 104 | PASS |
| `garage_raw.anrufe` Zeilen | 10 | 10 | PASS |
| Zweiter Lauf mit demselben Datum, gleiche Zeilenzahlen | gleich | 199 / 189 / 104 / 10 | PASS |
| Dateien unter `gs://daeng-haurikim-9gjm-raw/garage/version=2026-11-17/` | 4 | 4 | PASS |

## Akzeptanzkriterien Transformation (SPEC-TRANSFORM.md)

| Kriterium | Soll | Ist | Ergebnis |
|---|---|---|---|
| `dbt build` ohne Fehler, nur Datenqualitäts-Tests warnen | 0 ERROR | 0 ERROR, 5 WARN (alle Datenqualität) | PASS |
| `mart_wartezeit_woche` Zeilen | 2 | 2 | PASS |
| Woche 47: n_anfragen | 60 | 60 | PASS |
| Woche 47: n_mit_wartezeit | 60 | 60 | PASS |
| Woche 47: mittlere_wartezeit | 2.92 | 2.92 | PASS |
| Woche 47: mittlere_verschiebung | 0.80 | 0.8 | PASS |
| Woche 47: ablehnungsquote | 0.100 | 0.1 | PASS |
| Woche 47: n_unplausibel | 0 | 0 | PASS |
| Woche 48: n_anfragen | 44 | 44 | PASS |
| Woche 48: n_mit_wartezeit | 42 | 42 | PASS |
| Woche 48: mittlere_wartezeit | 2.64 | 2.64 | PASS |
| Woche 48: mittlere_verschiebung | 0.57 | 0.57 | PASS |
| Woche 48: ablehnungsquote | 0.182 | 0.182 | PASS |
| Woche 48: n_unplausibel | 2 | 2 | PASS |
| `mart_termine_tag` Zeilen | 20 | 20 | PASS |
| `mart_termine_tag` Summe n_termine | 199 | 199 | PASS |
| `mart_termine_tag` kleinster Tag | 7 | 7 | PASS |
| `mart_termine_tag` grösster Tag | 13 | 13 | PASS |
| `mart_erfassung_tag` Zeilen | 10 | 10 | PASS |
| `mart_erfassung_tag` befund «prüfen» | 17.11., 24.11., 25.11.2026 | 17.11. (0.389), 24.11. (0.375), 25.11.2026 (0.417) | PASS |
| `datenstatus = 'synthetisch'` in jeder Mart-Zeile | 32 von 32 | 32 von 32 | PASS |

BigQuery gibt 0.80 als `0.8` und 0.100 als `0.1` aus; der Wert ist derselbe.

## Tests

Harte Tests (severity error): 17 von 17 PASS (unique/not_null auf den vier Schlüsseln, 5 relationships,
accepted_values auf `stg_anfragen.kanal`, 3 singuläre Tests auf den Marts).

Datenqualitäts-Tests (severity warn), bekannte und dokumentierte Befunde:

| Test | Befund | Zeilen |
|---|---|---|
| `not_null_stg_reifenhotel_wechsel_status` | Radsätze ohne vermerkten Herbstwechsel | 152 |
| `dq_termine_auftragsart_klar` | Terminbuch-Einträge mit Auftragsart «unklar» | 7 |
| `dq_anfragen_plausibel` | Anfragen ohne Termin oder mit Termin vor der Anfrage | 2 |
| `dq_anfragen_kanal_bekannt` | Anfrage ohne erfassten Kanal | 1 |
| `not_null_stg_anfragen_erster_angebotener_termin` | Anfrage ohne angebotenen Termin | 1 |

## Schwierigkeiten bei der Umsetzung

1. **Rechnungskonto-Name.** Die Kursregel verlangt ein Konto mit «Education» im Namen. Das einzige offene Konto
   heisst «Rechnungskonto für Bildungszwecke» (deutsche Anzeige). Erst nach Bestätigung durch die Person, dass es
   das Education-Konto ist, wurde das Projekt damit verknüpft.
2. **Budget-Fehler `USER_PROJECT_DENIED`.** `gcloud billing budgets create` scheiterte direkt nach dem Anlegen des
   Projekts, weil die Berechtigung für das neue Projekt noch nicht überall angekommen war. Beim zweiten Versuch
   brach der Befehl beim Einfügen auf zwei Zeilen um, sodass das Budget nur mit der 50-%-Schwelle entstand;
   90 % und 100 % wurden mit `gcloud billing budgets update --add-threshold-rule` ergänzt. Heute: 50 USD,
   Schwellen 50/90/100 %, `EXCLUDE_ALL_CREDITS`.
3. **Compute-API abgelehnt.** Beim Setzen von `compute/region` bot gcloud an, die Compute-API einzuschalten.
   Die Frage wurde mit Nein beantwortet, weil Compute im Kurs nicht erlaubt ist; die Region ist trotzdem gesetzt.
4. **Seed-Typen.** Die Spaltentypen der Seeds standen zuerst gemeinsam für beide Seeds in `dbt_project.yml`,
   dbt warnte über Spalten, die es im jeweiligen Seed nicht gibt. Jetzt hat jeder Seed seine eigenen Typen,
   die Warnung ist weg.
