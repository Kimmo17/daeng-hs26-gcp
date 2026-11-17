-- Datenqualität (warn). Einige Einträge im Terminbuch liessen sich keiner Auftragsart zuordnen.
-- Bekannter Befund; der Mart zählt sie je Tag, die Terminzahl stimmt trotzdem.
{{ config(severity='warn') }}

SELECT eintrag_nr, datum, auftragsart
FROM {{ ref('stg_termine') }}
WHERE auftragsart = 'unklar'
