-- Die Kanäle kommen aus einem Seed, weil sie fachlich festgelegt sind: ein neuer Kanal in den Daten
-- soll im Test auffallen, statt still eine neue Kategorie zu erzeugen.

SELECT
    kanal_code,
    bezeichnung
FROM {{ ref('kanal') }}
