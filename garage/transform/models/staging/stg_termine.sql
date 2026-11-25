-- Typen erst hier setzen: ein Formatfehler im Terminbuch wird so zu NULL und von einem Test gefunden,
-- statt dass schon das Laden oder dbt abbricht.

SELECT
    SAFE_CAST(eintrag_nr AS INT64) AS eintrag_nr,
    SAFE.PARSE_DATE('%Y-%m-%d', datum) AS datum,
    -- Im Buch steht manchmal 10.00 statt 10:00; einheitlich, damit Zeiten vergleichbar sind.
    REPLACE(TRIM(zeit), '.', ':') AS zeit,
    kunde_pseudo,
    arbeit_freitext,
    -- Leerer Vermerk heisst "nichts notiert", nicht "leerer Text".
    NULLIF(TRIM(status_vermerk), '') AS status_vermerk,
    -- Nur ja und nein sind gültig; alles andere wird NULL und fällt auf.
    CASE radiert WHEN 'ja' THEN TRUE WHEN 'nein' THEN FALSE END AS ist_radiert,
    CASE nachgetragen WHEN 'ja' THEN TRUE WHEN 'nein' THEN FALSE END AS ist_nachgetragen,
    TRIM(auftragsart_codiert) AS auftragsart,
    -- Die Mart-Zeilen sollen sagen, aus welcher Lieferung sie stammen.
    {{ neueste_version() }} AS datenversion
FROM {{ source('garage_raw', 'terminbuch') }}
-- Literal statt Unterabfrage: so liest BigQuery nur die Partition dieser Version.
WHERE _PARTITIONDATE = {{ neueste_version() }}
