-- IR-03: Wie lange wartet eine Anfrage bis zum ersten angebotenen Termin, je Woche?
-- Die Fallzahl steht neben dem Mittelwert, weil ein Mittelwert aus wenigen Anfragen täuscht.
-- n_anfragen zählt alle Anfragen, damit die Ablehnungsquote sich auf alle bezieht, auch unplausible.

SELECT
    d.iso_jahr,
    d.iso_woche,
    COUNT(*) AS n_anfragen,
    COUNT(a.wartezeit_arbeitstage) AS n_mit_wartezeit,
    ROUND(AVG(a.wartezeit_arbeitstage), 2) AS mittlere_wartezeit,
    ROUND(AVG(a.verschiebung_ggue_wunsch), 2) AS mittlere_verschiebung,
    ROUND(SAFE_DIVIDE(COUNTIF(a.ist_angenommen = FALSE), COUNT(*)), 3) AS ablehnungsquote,
    COUNTIF(NOT a.ist_plausibel) AS n_unplausibel,
    COUNT(a.wartezeit_arbeitstage) >= {{ var('mindestfallzahl') }} AS ist_aussagekraeftig,
    '{{ var("datenstatus") }}' AS datenstatus
FROM {{ ref('fct_anfrage') }} AS a
JOIN {{ ref('dim_datum') }} AS d
    ON d.datum = a.anfrage_datum
GROUP BY d.iso_jahr, d.iso_woche
