-- Datenqualität (warn). Anfragen ohne erfassten Kanal sind ein bekannter Befund aus dem Profiling.
-- Sichtbar machen, damit die Erfassung verbessert wird, aber die Wartezeit nicht blockieren.
{{ config(severity='warn') }}

SELECT anfrage_nr, anfrage_datum
FROM {{ ref('stg_anfragen') }}
WHERE kanal = 'unbekannt'
