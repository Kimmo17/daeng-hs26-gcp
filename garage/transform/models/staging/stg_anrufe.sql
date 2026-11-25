-- Die Anrufstatistik ist der Nenner der Kontrolle G-02; als Zahl, damit man teilen kann.

SELECT
    SAFE.PARSE_DATE('%Y-%m-%d', datum) AS datum,
    SAFE_CAST(anrufe_total AS INT64) AS anrufe_total,
    SAFE_CAST(anrufe_verpasst AS INT64) AS anrufe_verpasst,
    SAFE_CAST(anrufe_angenommen AS INT64) AS anrufe_angenommen,
    -- Die Mart-Zeilen sollen sagen, aus welcher Lieferung sie stammen.
    {{ neueste_version() }} AS datenversion
FROM {{ source('garage_raw', 'anrufe') }}
-- Literal statt Unterabfrage: so liest BigQuery nur die Partition dieser Version.
WHERE _PARTITIONDATE = {{ neueste_version() }}
