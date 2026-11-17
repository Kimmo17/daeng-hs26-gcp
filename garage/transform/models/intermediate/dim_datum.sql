-- Ein lückenloser Kalender über alle Quellen. So hat jeder Fakt ein Datum im Schema, und Tage ohne
-- Einträge existieren trotzdem, statt einfach zu fehlen.

WITH grenzen AS (
    SELECT MIN(d) AS von, MAX(d) AS bis
    FROM (
        SELECT datum AS d FROM {{ ref('stg_termine') }}
        UNION ALL
        SELECT anfrage_datum FROM {{ ref('stg_anfragen') }}
        UNION ALL
        SELECT datum FROM {{ ref('stg_anrufe') }}
    )
)

SELECT
    datum,
    -- ISO-Jahr und ISO-Woche, weil der Inhaber in Kalenderwochen denkt und die Woche am Montag beginnt.
    EXTRACT(ISOYEAR FROM datum) AS iso_jahr,
    EXTRACT(ISOWEEK FROM datum) AS iso_woche,
    CASE EXTRACT(DAYOFWEEK FROM datum)
        WHEN 1 THEN 'Sonntag'
        WHEN 2 THEN 'Montag'
        WHEN 3 THEN 'Dienstag'
        WHEN 4 THEN 'Mittwoch'
        WHEN 5 THEN 'Donnerstag'
        WHEN 6 THEN 'Freitag'
        WHEN 7 THEN 'Samstag'
    END AS wochentag,
    -- Gleiche Definition wie im Makro arbeitstage_zwischen: Montag bis Freitag, ohne Feiertage.
    EXTRACT(DAYOFWEEK FROM datum) BETWEEN 2 AND 6 AS ist_arbeitstag
FROM grenzen, UNNEST(GENERATE_DATE_ARRAY(von, bis)) AS datum
