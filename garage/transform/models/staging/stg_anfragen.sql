-- Typisierte Anfrageliste. Unplausible Zeilen bleiben drin und werden nur markiert,
-- damit der Mart zeigen kann, wie viele es sind, statt sie still zu verlieren.

WITH typisiert AS (
    SELECT
        anfrage_nr,
        SAFE.PARSE_DATE('%Y-%m-%d', anfrage_datum) AS anfrage_datum,
        SAFE.PARSE_DATE('%Y-%m-%d', wunschtag) AS wunschtag,
        SAFE.PARSE_DATE('%Y-%m-%d', erster_angebotener_termin) AS erster_angebotener_termin,
        anfrage_zeit,
        -- Ein fehlender Kanal ist ein eigener Wert, damit die Anfrage im Star-Schema einen Partner hat
        -- und die Lücke in der Erfassung zählbar bleibt.
        COALESCE(NULLIF(TRIM(kanal), ''), 'unbekannt') AS kanal,
        TRIM(auftragsart) AS auftragsart,
        CASE angenommen WHEN 'ja' THEN TRUE WHEN 'nein' THEN FALSE END AS ist_angenommen,
        NULLIF(TRIM(grund_ablehnung), '') AS grund_ablehnung,
        -- Die Mart-Zeilen sollen sagen, aus welcher Lieferung sie stammen.
        {{ neueste_version() }} AS datenversion
    FROM {{ source('garage_raw', 'anfragen') }}
    -- Literal statt Unterabfrage: so liest BigQuery nur die Partition dieser Version.
    WHERE _PARTITIONDATE = {{ neueste_version() }}
)

SELECT
    *,
    -- Ohne angebotenen Termin oder mit einem Termin vor der Anfrage gibt es keine sinnvolle Wartezeit.
    COALESCE(
        erster_angebotener_termin IS NOT NULL AND erster_angebotener_termin >= anfrage_datum,
        FALSE
    ) AS ist_plausibel
FROM typisiert
