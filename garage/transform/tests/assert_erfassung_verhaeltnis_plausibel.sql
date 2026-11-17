-- Hart. Mehr als anderthalb Telefon-Einträge pro angenommenem Anruf sind fachlich kaum möglich.
-- Ein solcher Wert heisst, dass die Verknüpfung von Anfragen und Anrufen nicht stimmt
-- (etwa falsches Datum oder doppelte Zeilen), und dann ist auch jeder Befund "ok" wertlos.

SELECT datum, verhaeltnis
FROM {{ ref('mart_erfassung_tag') }}
WHERE verhaeltnis > 1.5
