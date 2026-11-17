-- Hart. Schützt die Körnung von mart_wartezeit_woche: eine Zeile pro ISO-Woche. Zwei Zeilen für
-- dieselbe Woche hiessen, dass der Join auf dim_datum vervielfacht, und der Inhaber sähe zwei Mittelwerte.

SELECT iso_jahr, iso_woche, COUNT(*) AS n_zeilen
FROM {{ ref('mart_wartezeit_woche') }}
GROUP BY iso_jahr, iso_woche
HAVING COUNT(*) > 1
