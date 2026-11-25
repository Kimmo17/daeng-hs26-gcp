-- Grain: ein Eintrag im Terminbuch. Radierte und nachgetragene Einträge bleiben drin und sind nur
-- gekennzeichnet, weil der Mart sie gesondert zählt (nachgetragen = Notfall, radiert = abgesagt).

SELECT
    eintrag_nr,
    datum,
    zeit,
    auftragsart,
    kunde_pseudo,
    ist_radiert,
    ist_nachgetragen,
    status_vermerk,
    datenversion
FROM {{ ref('stg_termine') }}
