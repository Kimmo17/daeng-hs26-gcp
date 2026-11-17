{#-
    Anzahl Arbeitstage (Montag bis Freitag) im Intervall (start, ende]: ohne den Starttag, mit dem Endtag.
    Entspricht NETZWERKTAGE(start; ende) - 1 in Excel, damit die Zahlen mit den Abgaben aus Woche 8
    übereinstimmen. Feiertage werden nicht berücksichtigt (Annahme).
    NULL, wenn ein Datum fehlt oder ende vor start liegt: eine negative Wartezeit wäre ein Erfassungsfehler,
    keine Kennzahl, und soll den Mittelwert nicht verfälschen.
-#}
{% macro arbeitstage_zwischen(start, ende) -%}
    CASE
        WHEN {{ start }} IS NULL OR {{ ende }} IS NULL OR {{ ende }} < {{ start }} THEN NULL
        ELSE (
            SELECT COUNT(*)
            FROM UNNEST(GENERATE_DATE_ARRAY({{ start }}, {{ ende }})) AS tag
            -- DAYOFWEEK: 1 = Sonntag, 7 = Samstag
            WHERE tag > {{ start }}
              AND EXTRACT(DAYOFWEEK FROM tag) BETWEEN 2 AND 6
        )
    END
{%- endmacro %}
