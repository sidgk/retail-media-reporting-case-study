{#- Which event days a model reads. Incremental runs read only run_date minus the lookback, which
    is what keeps a 1TB-a-day source affordable. Backfill by passing run_date and lookback_days. -#}
{% macro event_window(column) %}
    {% if is_incremental() %}
        {{ column }} between unix_date(date '{{ var("run_date") }}') - {{ var("lookback_days") }}
                         and unix_date(date '{{ var("run_date") }}')
    {% else %}
        {{ column }} >= unix_date(date '{{ var("start_date") }}')
    {% endif %}
{% endmacro %}
