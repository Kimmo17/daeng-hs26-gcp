SPEZIFIKATION TRANSFORMATION

Ziel: Ein dbt-Projekt unter garage/transform/, das aus garage_raw ein kleines Star-Schema und drei Marts für den Inhaber der Garage Keller baut. Es wird lokal in WSL gestartet (dbt build), nicht als Cloud-Run-Job. Das Projekt ist Abgabe in einem BI-Modul: wenige Modelle, sprechende Namen, deutsche Kommentare im SQL, die sagen warum, nicht was. Keine dbt-Packages. Als Muster für Aufbau, Profil und generate_schema_name dient referenz/transform/ (bitte dort nachsehen).

Dateien unter garage/transform/: dbt_project.yml (Projektname garage_transform), profiles.yml, requirements.txt (dbt-core und dbt-bigquery, beide >=1.10,<2), README.md (zehn Zeilen), macros/generate_schema_name.sql, macros/arbeitstage_zwischen.sql, seeds/auftragsart.csv, seeds/kanal.csv, models/sources.yml, models/staging/*.sql, models/intermediate/*.sql, models/marts/*.sql, models/schema.yml, tests/*.sql.

Profil: method oauth (Application Default Credentials, kein Schlüssel), project aus der Umgebungsvariable DBT_PROJECT, location europe-west6, ein target prod, profiles.yml im Projektordner.

Datasets: genau garage_staging, garage_intermediate, garage_marts. generate_schema_name so überschreiben, dass das custom schema wörtlich verwendet wird. Seeds landen in garage_intermediate.

Variablen in dbt_project.yml (mit Kommentar, warum sie Variablen sind):
- datenstatus: "synthetisch". Jede Zeile jedes Marts trägt diese Spalte. Sobald echte Daten kommen, wird nur die Variable geändert.
- mindestfallzahl: 20. Unter dieser Fallzahl gilt eine Wochenzahl als nicht aussagekräftig (IR-03, zu vereinbaren mit dem Inhaber).
- schwelle_erfassung: 0.5. Verhältnis Einträge Telefon zu angenommenen Anrufen, unter dem ein Tag geprüft werden muss (W8, zu vereinbaren).

Makro arbeitstage_zwischen(start, ende): Anzahl Montag bis Freitag im Intervall (start, ende], also ohne den Starttag und mit dem Endtag. Umsetzung mit GENERATE_DATE_ARRAY und EXTRACT(DAYOFWEEK). Liefert NULL, wenn eines der Daten NULL ist oder ende vor start liegt. Kommentar: entspricht NETZWERKTAGE(start; ende) − 1 in Excel, damit die Zahlen mit den Abgaben aus Woche 8 übereinstimmen; Feiertage werden nicht berücksichtigt (Annahme).

Seeds:
- auftragsart.csv: auftragsart_code, bezeichnung, mit Service, Reparatur, Reifenwechsel, MFK-Vorbereitung, unklar.
- kanal.csv: kanal_code, bezeichnung, mit Telefon, Theke, E-Mail, unbekannt.

Staging (table, garage_staging), Spalten typisiert:
- stg_termine aus raw.terminbuch: eintrag_nr (INT64), datum (DATE), zeit (STRING, normiert auf HH:MM: ein Punkt wird zum Doppelpunkt), kunde_pseudo, arbeit_freitext, status_vermerk (leer als NULL), ist_radiert (BOOL aus ja/nein), ist_nachgetragen (BOOL), auftragsart (aus auftragsart_codiert).
- stg_reifenhotel aus raw.reifenhotel: satz_nr, kunde_pseudo, einlagerung_datum (DATE), dimension (normiert: Grossbuchstaben, ohne Leerzeichen), lagerplatz, wechsel_status (leer als NULL).
- stg_anfragen aus raw.anfragen: anfrage_nr, anfrage_datum, wunschtag, erster_angebotener_termin (DATE), anfrage_zeit, kanal (leer wird "unbekannt"), auftragsart, ist_angenommen (BOOL), grund_ablehnung (leer als NULL), sowie ist_plausibel (BOOL): falsch, wenn erster_angebotener_termin fehlt oder vor anfrage_datum liegt. Unplausible Zeilen bleiben drin, damit man sie zählen kann.
- stg_anrufe aus raw.anrufe: datum (DATE), anrufe_total, anrufe_verpasst, anrufe_angenommen (INT64).
Alle Datumsumwandlungen mit SAFE.PARSE_DATE('%Y-%m-%d', ...), damit ein Formatfehler NULL ergibt und ein Test ihn findet, statt dass dbt abbricht.

Intermediate (table, garage_intermediate), das Star-Schema:
- dim_datum: eine Zeile pro Kalendertag vom kleinsten bis zum grössten Datum aus stg_termine, stg_anfragen und stg_anrufe, mit iso_jahr, iso_woche, wochentag (Name, deutsch), ist_arbeitstag.
- dim_auftragsart und dim_kanal aus den Seeds.
- fct_termin: Grain ein Eintrag im Terminbuch. Schlüssel eintrag_nr. Fremdschlüssel datum, auftragsart. Kennzeichen ist_radiert, ist_nachgetragen, status_vermerk.
- fct_anfrage: Grain eine Terminanfrage. Schlüssel anfrage_nr. Fremdschlüssel anfrage_datum, kanal, auftragsart. Kennzahlen wartezeit_arbeitstage = arbeitstage_zwischen(anfrage_datum, erster_angebotener_termin) und verschiebung_ggue_wunsch = arbeitstage_zwischen(wunschtag, erster_angebotener_termin), beide nur bei ist_plausibel, sonst NULL. Kommentar im SQL: Die Wartezeit nach Glossar enthält auch den Wunsch der Kundschaft nach einem späteren Tag; erst die Verschiebung gegenüber dem Wunschtag zeigt den Engpass.

Marts (table, garage_marts, full refresh). Jede Zeile hat die Spalte datenstatus aus der Variable:
- mart_wartezeit_woche (IR-03): iso_jahr, iso_woche, n_anfragen (alle), n_mit_wartezeit, mittlere_wartezeit (auf 2 Stellen), mittlere_verschiebung (auf 2 Stellen), ablehnungsquote (Anteil ist_angenommen = false an allen Anfragen), n_unplausibel, ist_aussagekraeftig (n_mit_wartezeit >= mindestfallzahl), datenstatus. Eine Zeile pro Woche.
- mart_termine_tag (IR-01, eingeschränkt): datum, wochentag, n_termine, n_notfaelle (ist_nachgetragen), n_radiert, n_auftragsart_unklar, hinweis (fester Text: "Nur Terminzahl. Planungsquote nicht berechenbar, Aufwand fehlt (E-02)."), datenstatus. Eine Zeile pro Arbeitstag mit Einträgen.
- mart_erfassung_tag (Kontrolle G-02): datum, anrufe_angenommen, eintraege_telefon (Anfragen mit kanal Telefon an diesem Tag), verhaeltnis (auf 3 Stellen), befund ("prüfen" unter schwelle_erfassung, sonst "ok"), datenstatus. Eine Zeile pro Tag aus stg_anrufe.

sources.yml: Quelle garage_raw mit vier Tabellen, je eine Beschreibung in einem Satz, die "synthetisch" erwähnt.

Tests. Zwei Arten, mit Kommentar, was sie schützen:
1. Harte Tests (severity error, Standard), schützen das Modell: unique und not_null auf fct_termin.eintrag_nr, fct_anfrage.anfrage_nr, dim_datum.datum, stg_anrufe.datum. relationships von fct_anfrage.kanal zu dim_kanal.kanal_code, von fct_anfrage.auftragsart und fct_termin.auftragsart zu dim_auftragsart.auftragsart_code, von fct_anfrage.anfrage_datum und fct_termin.datum zu dim_datum.datum. accepted_values auf stg_anfragen.kanal. Singular tests: (a) mart_wartezeit_woche eine Zeile pro (iso_jahr, iso_woche), (b) in mart_erfassung_tag kein verhaeltnis über 1.5 (sonst stimmt die Verknüpfung nicht), (c) jede Zeile jedes Marts hat datenstatus nicht NULL.
2. Datenqualitäts-Tests (severity warn), die wie das Profiling aus Woche 7 und 8 Befunde melden, ohne die Pipeline zu stoppen: not_null auf stg_anfragen.erster_angebotener_termin, stg_anfragen ohne "unbekannt" als kanal (singular), stg_anfragen ist_plausibel ist überall wahr (singular), stg_termine ohne auftragsart "unklar" (singular), stg_reifenhotel.wechsel_status not_null. Begründung im Kommentar: Diese Befunde sind bekannt und dokumentiert (T-03 bis T-05, PR-08, PR-16); sie sollen sichtbar sein, aber die Antwort nicht verhindern.

Akzeptanzkriterien (die Zahlen stammen aus den Excel-Abgaben W7 und W8 und müssen genau getroffen werden):
- dbt build läuft ohne Fehler durch; nur die Datenqualitäts-Tests melden Warnungen.
- mart_wartezeit_woche: zwei Zeilen. Woche 47: n_anfragen 60, n_mit_wartezeit 60, mittlere_wartezeit 2.92, mittlere_verschiebung 0.80, ablehnungsquote 0.100, n_unplausibel 0. Woche 48: n_anfragen 44, n_mit_wartezeit 42, mittlere_wartezeit 2.64, mittlere_verschiebung 0.57, ablehnungsquote 0.182, n_unplausibel 2.
- mart_termine_tag: 20 Zeilen, Summe n_termine 199, kleinster Tag 7, grösster 13 Termine.
- mart_erfassung_tag: 10 Zeilen, befund "prüfen" genau am 17.11., 24.11. und 25.11.2026.
- Jede Mart-Zeile hat datenstatus = "synthetisch".

Nicht tun: keine Packages (kein dbt_utils), kein incremental, keine Views, keinen Cloud-Run-Job, keine Änderung an garage_raw oder an Dateien ausserhalb von garage/, keine Zahlen im SQL hart codieren, die als Variable vorgesehen sind.
