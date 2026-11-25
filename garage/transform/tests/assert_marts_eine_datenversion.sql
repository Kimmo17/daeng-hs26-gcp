-- Hart. Jede Lieferung ist ein vollständiger Stand; stünden zwei Versionen in einem Mart, wären Zeilen
-- doppelt gezählt. Ein leerer Mart (0 Versionen) fällt ebenfalls auf, statt still leer beim Inhaber zu landen.

SELECT 'mart_wartezeit_woche' AS mart, COUNT(DISTINCT datenversion) AS n_versionen
FROM {{ ref('mart_wartezeit_woche') }}
HAVING COUNT(DISTINCT datenversion) != 1

UNION ALL

SELECT 'mart_termine_tag', COUNT(DISTINCT datenversion)
FROM {{ ref('mart_termine_tag') }}
HAVING COUNT(DISTINCT datenversion) != 1

UNION ALL

SELECT 'mart_erfassung_tag', COUNT(DISTINCT datenversion)
FROM {{ ref('mart_erfassung_tag') }}
HAVING COUNT(DISTINCT datenversion) != 1
