-- Die Reifendimension steht in mehreren Schreibweisen in der Liste (205/55 r16, 205/55R16 ...).
-- Einheitlich, damit dieselbe Dimension beim Zählen nicht als mehrere erscheint.

SELECT
    satz_nr,
    kunde_pseudo,
    SAFE.PARSE_DATE('%Y-%m-%d', einlagerung_datum) AS einlagerung_datum,
    UPPER(REPLACE(dimension, ' ', '')) AS dimension,
    lagerplatz,
    -- Leer heisst "kein Wechsel vermerkt"; als NULL zählt es der Datenqualitäts-Test.
    NULLIF(TRIM(wechsel_herbst_2026), '') AS wechsel_status,
    -- Die Mart-Zeilen sollen sagen, aus welcher Lieferung sie stammen.
    {{ neueste_version() }} AS datenversion
FROM {{ source('garage_raw', 'reifenhotel') }}
-- Literal statt Unterabfrage: so liest BigQuery nur die Partition dieser Version.
WHERE _PARTITIONDATE = {{ neueste_version() }}
