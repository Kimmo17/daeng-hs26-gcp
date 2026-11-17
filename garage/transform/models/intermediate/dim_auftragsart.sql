-- Die Liste der Auftragsarten kommt aus einem Seed, weil sie fachlich festgelegt ist und nicht aus
-- den Daten abgeleitet werden soll: eine neue Schreibweise in den Daten fällt so im Test auf.

SELECT
    auftragsart_code,
    bezeichnung
FROM {{ ref('auftragsart') }}
