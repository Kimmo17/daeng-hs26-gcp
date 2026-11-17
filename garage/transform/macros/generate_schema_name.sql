{#-
    Ohne dieses Makro hängt dbt ein custom schema an das Standard-Dataset an: aus +schema: garage_marts
    würde garage_staging_garage_marts. Wir wollen genau die drei Datasets garage_staging,
    garage_intermediate und garage_marts, deshalb nehmen wir das custom schema wörtlich.
-#}
{% macro generate_schema_name(custom_schema_name, node) -%}
    {%- if custom_schema_name is none -%}
        {{ target.schema }}
    {%- else -%}
        {{ custom_schema_name | trim }}
    {%- endif -%}
{%- endmacro %}
