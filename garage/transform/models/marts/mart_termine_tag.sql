-- IR-01, eingeschränkt: nur wie viele Termine je Arbeitstag im Buch stehen. Eine Planungsquote
-- bräuchte den Aufwand je Termin, und der fehlt (Data Gap Map E-02). Der Hinweis steht in jeder Zeile,
-- damit niemand die Terminzahl als Auslastung liest.

SELECT
    t.datum,
    d.wochentag,
    COUNT(*) AS n_termine,
    COUNTIF(t.ist_nachgetragen) AS n_notfaelle,
    COUNTIF(t.ist_radiert) AS n_radiert,
    COUNTIF(t.auftragsart = 'unklar') AS n_auftragsart_unklar,
    'Nur Terminzahl. Planungsquote nicht berechenbar, Aufwand fehlt (E-02).' AS hinweis,
    '{{ var("datenstatus") }}' AS datenstatus,
    t.datenversion
FROM {{ ref('fct_termin') }} AS t
JOIN {{ ref('dim_datum') }} AS d
    ON d.datum = t.datum
WHERE d.ist_arbeitstag
GROUP BY t.datum, d.wochentag, t.datenversion
