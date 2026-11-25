{#-
    Gibt die Datenversion als Datumsliteral zurück, zum Beispiel DATE '2026-12-14'.

    garage_raw hält jede Lieferung als eigene Partition. Jede Lieferung ist ein vollständiger Stand
    (Snapshot), läsen wir mehrere, käme jede Zeile einmal pro Version vor. Deshalb liest jedes
    Staging-Modell genau eine Partition.

    Gewählt wird die neueste Version, für die alle vier Tabellen im ladeprotokoll stehen. Der
    Ingest-Job schreibt das Protokoll erst am Schluss, eine halb geladene Version zählt so nie.
    Mit dbt build --vars '{version: "2026-11-17"}' gilt die angegebene Version, damit sich jeder
    ältere Stand reproduzieren lässt.

    Die Version wird beim Kompilieren abgefragt und als fester Wert ins SQL geschrieben, denn nur bei
    einem festen Wert liest BigQuery allein diese eine Partition.
-#}
{% macro neueste_version() %}
    {#- Ausserhalb von "if execute", damit dbt das Protokoll als Quelle jedes Staging-Modells kennt (Lineage). -#}
    {%- set protokoll = source('garage_raw', 'ladeprotokoll') -%}
    {%- if execute -%}
        {%- set gewuenscht = var('version', none) -%}
        {%- if gewuenscht -%}
            {#- Die Variable landet als Literal im SQL; nur ein Datum ist erlaubt, nichts anderes. -#}
            {%- if not modules.re.fullmatch('[0-9]{4}-[0-9]{2}-[0-9]{2}', gewuenscht | string) -%}
                {{ exceptions.raise_compiler_error("Variable version muss JJJJ-MM-TT sein, ist aber '" ~ gewuenscht ~ "'") }}
            {%- endif -%}
            {%- set version = gewuenscht | string -%}
            {%- set herkunft = "Variable version" -%}
        {%- else -%}
            {%- set result = run_query(
                "SELECT CAST(MAX(version) AS STRING) FROM ("
                ~ " SELECT version FROM " ~ protokoll
                ~ " GROUP BY version HAVING COUNT(DISTINCT tabelle) = 4)"
            ) -%}
            {%- set version = result.columns[0].values()[0] -%}
            {%- if version is none -%}
                {{ exceptions.raise_compiler_error("garage_raw.ladeprotokoll enthält keine vollständige Version, es gibt nichts zu verarbeiten") }}
            {%- endif -%}
            {%- set herkunft = "ladeprotokoll" -%}
        {%- endif -%}
        {{ log("Datenversion " ~ version ~ " (" ~ herkunft ~ ") für " ~ model.name, info=true) }}
        DATE '{{ version }}'
    {%- else -%}
        {#- Beim Parsen fragt dbt nichts ab; der Platzhalter wird nie ausgeführt. -#}
        DATE '1970-01-01'
    {%- endif -%}
{% endmacro %}
