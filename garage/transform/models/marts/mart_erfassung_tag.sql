-- Kontrolle G-02: Wird die Anfrageliste lückenlos geführt? Jeder angenommene Anruf könnte eine Anfrage
-- sein; stehen deutlich weniger Telefon-Einträge in der Liste, wurde vermutlich nicht alles notiert.
-- Grundlage sind die Tage der Anrufstatistik, damit ein Tag ohne einen einzigen Eintrag nicht fehlt.

WITH eintraege AS (
    SELECT
        anfrage_datum AS datum,
        COUNT(*) AS eintraege_telefon
    FROM {{ ref('fct_anfrage') }}
    WHERE kanal = 'Telefon'
    GROUP BY anfrage_datum
),

verglichen AS (
    SELECT
        r.datum,
        r.anrufe_angenommen,
        COALESCE(e.eintraege_telefon, 0) AS eintraege_telefon,
        SAFE_DIVIDE(COALESCE(e.eintraege_telefon, 0), r.anrufe_angenommen) AS verhaeltnis_roh,
        r.datenversion
    FROM {{ ref('stg_anrufe') }} AS r
    LEFT JOIN eintraege AS e
        ON e.datum = r.datum
)

SELECT
    datum,
    anrufe_angenommen,
    eintraege_telefon,
    ROUND(verhaeltnis_roh, 3) AS verhaeltnis,
    -- Verglichen wird der ungerundete Wert, damit die Rundung keinen Tag über die Schwelle hebt.
    CASE WHEN verhaeltnis_roh < {{ var('schwelle_erfassung') }} THEN 'prüfen' ELSE 'ok' END AS befund,
    '{{ var("datenstatus") }}' AS datenstatus,
    datenversion
FROM verglichen
