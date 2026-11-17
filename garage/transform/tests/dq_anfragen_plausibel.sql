-- Datenqualität (warn). Anfragen ohne angebotenen Termin oder mit einem Termin vor der Anfrage sind
-- bekannte Erfassungsfehler. Sie fallen aus dem Mittelwert, werden im Mart gezählt und hier gemeldet.
{{ config(severity='warn') }}

SELECT anfrage_nr, anfrage_datum, erster_angebotener_termin
FROM {{ ref('stg_anfragen') }}
WHERE NOT ist_plausibel
