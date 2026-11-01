{#- One switch for partitioning. A sandbox silently expires DATE partitions older than 60 days,
    so dev partitions on an integer day number. copy_partitions swaps whole partitions with the
    copy API, which avoids MERGE: cheaper at volume, and the only option on a sandbox. -#}
{% macro day_partition() %}
    {% if var('use_date_partitions') %}
        {{ return({'field': 'event_date', 'data_type': 'date', 'granularity': 'day', 'copy_partitions': true}) }}
    {% else %}
        {{ return({'field': 'event_day', 'data_type': 'int64', 'range': {'start': 18000, 'end': 28000, 'interval': 1}, 'copy_partitions': true}) }}
    {% endif %}
{% endmacro %}
