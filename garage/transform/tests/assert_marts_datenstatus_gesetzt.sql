-- Hart. Keine Zahl soll ohne den Hinweis auf ihren Datenstatus beim Inhaber landen; solange die Daten
-- synthetisch sind, wäre eine Zeile ohne diesen Hinweis irreführend.

SELECT 'mart_wartezeit_woche' AS mart, COUNT(*) AS n_ohne_status
FROM {{ ref('mart_wartezeit_woche') }}
WHERE datenstatus IS NULL
HAVING COUNT(*) > 0

UNION ALL

SELECT 'mart_termine_tag', COUNT(*)
FROM {{ ref('mart_termine_tag') }}
WHERE datenstatus IS NULL
HAVING COUNT(*) > 0

UNION ALL

SELECT 'mart_erfassung_tag', COUNT(*)
FROM {{ ref('mart_erfassung_tag') }}
WHERE datenstatus IS NULL
HAVING COUNT(*) > 0
