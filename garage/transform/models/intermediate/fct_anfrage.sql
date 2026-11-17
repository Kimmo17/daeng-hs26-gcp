-- Grain: eine Terminanfrage.
-- Die Wartezeit nach Glossar enthält auch den Wunsch der Kundschaft nach einem späteren Tag; erst die
-- Verschiebung gegenüber dem Wunschtag zeigt den Engpass. Deshalb rechnen wir beide.
-- Bei unplausiblen Anfragen bleiben beide NULL, damit ein Erfassungsfehler keinen Mittelwert verfälscht.

SELECT
    anfrage_nr,
    anfrage_datum,
    wunschtag,
    erster_angebotener_termin,
    kanal,
    auftragsart,
    ist_angenommen,
    grund_ablehnung,
    ist_plausibel,
    CASE WHEN ist_plausibel
        THEN {{ arbeitstage_zwischen('anfrage_datum', 'erster_angebotener_termin') }}
    END AS wartezeit_arbeitstage,
    CASE WHEN ist_plausibel
        THEN {{ arbeitstage_zwischen('wunschtag', 'erster_angebotener_termin') }}
    END AS verschiebung_ggue_wunsch
FROM {{ ref('stg_anfragen') }}
