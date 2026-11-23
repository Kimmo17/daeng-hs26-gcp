SPEZIFIKATION

Ziel: Ein Cloud-Run-Job untersucht eine fehlgeschlagene Execution des Workflows gtfs-pipeline so, wie es ein Mensch mit Zugang zur Console täte, und schreibt das Ergebnis als eine Zeile in die Tabelle ops.incidents. Der Job ist ein Agent nach dem Google Agent Development Kit: ein Sprachmodell (gemini-3.8-flash über Vertex AI, Location eu), eine Anweisung, Werkzeuge, ein Ausgabeschema. Der Job ist Lehrmaterial: Studierende lesen ihn, darum zwei Dateien, deutsche Kommentare, die sagen warum, und Docstrings der Werkzeuge auf Deutsch, weil das Modell sie liest.

Was der Agent darf: lesen. Workflow und seine Executions, die Cloud-Run-Jobs der Pipeline mit Konfiguration, Executions und Logzeilen, das Admin-Activity-Audit-Log von Jobs, Workflow und Scan, die Spezifikation und die Ergebnisse des Dataplex-Scans, die letzten Cloud Builds, die Load-Jobs einer Tabelle in raw, und BigQuery über das ADK-Werkzeug mit Schreibsperre, Obergrenze 1 GB pro Abfrage, ohne Leserolle auf raw (Metadaten und Zeilenzahlen ja, Zeileninhalte nein).

Was der Agent nicht darf: irgendetwas ändern. Kein Werkzeug schreibt, deployt, startet oder löscht. Die eine Schreiboperation, die Zeile in ops.incidents, macht das Programm nach dem Lauf des Modells, nicht das Modell. Der Service-Account hat Schreibrecht nur auf dem Dataset ops.

Eingabe: die Execution-ID als einziges Argument. Ist die Execution noch ACTIVE (der Workflow startet diesen Job aus seinem Fehlerzweig, bevor er selbst beendet ist), wartet der Job bis zu zwei Minuten.

Ausgabe, als Pydantic-Schema und output_schema des Agenten: category (Konfigurationsfehler, Code-Änderung, Regel zu streng, Berechtigung, Daten geändert, unklar), what_happened, where_to_look (Liste), facts (Liste, jeder Eintrag "Fakt (Werkzeug)"), inferences (Liste), cause, proposed_fix, confidence (hoch, mittel, tief, hoch nur, wenn die Ursache in facts steht).

Anweisung an das Modell: allgemein, ohne Nennung bestimmter Vorfälle. Vorgehen in fünf Schritten (Execution lesen, den gescheiterten Schritt lesen, mit der Historie vergleichen, nach Änderungen der letzten Tage suchen, die einfachste Erklärung wählen und Widersprüche nennen), die zwei Standardabfragen auf PARTITIONS und JOBS_BY_PROJECT (verdichtet, mit Zeitfilter, nie SELECT *), die Trennung von Fakten und Schlüssen, die Regel für die Konfidenz, und die Regel für Massnahmen: nur, was einen früheren Zustand wiederherstellt oder einen idempotenten Schritt wiederholt, keine Datenbereinigung ohne Beleg, immer als Vorschlag.

Werkzeuge: feste Namen aus der Umgebung (Projekt, Region, Workflow, Scan, erlaubte Jobs), knappe Antworten (Felder, Obergrenzen: 5 Executions, 40 Logzeilen, 20 Audit-Einträge, 3 Scan-Jobs, 5 Builds, 10 Load-Jobs), Fehler als Ergebnis statt Exception. Das Audit-Werkzeug rechnet bei SetIamPolicy das Delta der Bindungen und bei UpdateDataScan die geänderten Regeln gegenüber der vorigen Fassung aus.

Nachweis: pro Lauf jeden Werkzeugaufruf mit Argumenten, Länge und den ersten 300 Zeichen der Antwort in ops.incidents.tool_calls, dazu Modellversion, Token, Dauer. Obergrenze 30 Modellaufrufe pro Diagnose.

Selbsttest: main.py --selftest ruft jedes Werkzeug einmal auf und meldet pro Werkzeug OK oder den Fehler. Das ist die Prüfung der Rollen, bevor der erste Vorfall kommt.

Nicht tun: kein Werkzeug, das schreibt, keine Leserolle auf raw, keine Regel in der Anweisung, die einen bestimmten Vorfall beschreibt, kein zweiter Agent, kein Parsen der Modellantwort von Hand (das Schema macht das), kein Web-Server (adk deploy cloud_run erzeugt einen Service, wir brauchen einen Job).
