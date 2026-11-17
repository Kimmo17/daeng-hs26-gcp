-- Die Anrufstatistik ist der Nenner der Kontrolle G-02; als Zahl, damit man teilen kann.

SELECT
    SAFE.PARSE_DATE('%Y-%m-%d', datum) AS datum,
    SAFE_CAST(anrufe_total AS INT64) AS anrufe_total,
    SAFE_CAST(anrufe_verpasst AS INT64) AS anrufe_verpasst,
    SAFE_CAST(anrufe_angenommen AS INT64) AS anrufe_angenommen
FROM {{ source('garage_raw', 'anrufe') }}
