#!/bin/bash

TODAY=$(date '+%Y.%m.%d')
for ID in '001' '002'
do
    INDEX='tsdb_other_index_001'
    if [ $ID == '002' ] ; then
      INDEX='tsdb_index_001'
    fi
    echo "DELETE all datastreams and configurations for $INDEX"
    curl --request DELETE --url http://elastic:changeme@localhost:9200/_data_stream/$INDEX?pretty || true
    curl --request DELETE --url http://elastic:changeme@localhost:9200/_data_stream/.ds-$INDEX-$TODAY-000001-downsample || true
    curl --request DELETE --url http://elastic:changeme@localhost:9200/_index_template/$INDEX-index-template?pretty || true
    curl --request DELETE --url http://elastic:changeme@localhost:9200/_component_template/$INDEX-mappings?pretty || true

    echo "Create component template $INDEX"
    curl --request PUT \
            --url http://elastic:changeme@localhost:9200/_component_template/$INDEX-mappings?pretty \
            --header 'Content-Type: application/json' \
            --data "
        {
        \"template\": {
            \"settings\": {
                \"mode\": \"time_series\",
                \"routing_path\": [ \"sensor_id\", \"location\" ]
            },
            \"mappings\": {
                \"properties\": {
                    \"sensor_id\": {
                    \"type\": \"keyword\",
                    \"time_series_dimension\": true
                    },
                    \"location\": {
                    \"type\": \"keyword\",
                    \"time_series_dimension\": true
                    },
                    \"counter\": {
                    \"type\": \"double\",
                    \"time_series_metric\": \"counter\"
                    },
                    \"counter_as_double\": {
                    \"type\": \"double\"
                    },
                    \"temperature\": {
                    \"type\": \"half_float\",
                    \"time_series_metric\": \"gauge\"
                    },
                    \"humidity\": {
                    \"type\": \"half_float\",
                    \"time_series_metric\": \"gauge\"
                    },
                    \"@timestamp\": {
                    \"type\": \"date\",
                    \"format\": \"strict_date_optional_time\"
                    }
                }
            }
        },
        \"_meta\": {
            \"description\": \"Testing TSDB stream component template\"
        }
    }
    "
    echo "Create index template $INDEX"
    curl --request PUT \
            --url http://elastic:changeme@localhost:9200/_index_template/$INDEX-index-template?pretty \
            --header 'Content-Type: application/json' \
            --data "
            {
            \"index_patterns\": [\"$INDEX\"],
            \"data_stream\": { },
            \"composed_of\": [ \"$INDEX-mappings\"],
            \"_meta\": {
                \"description\": \"Template for $INDEX\"
            }
            }
    " 


    echo "Create $INDEX data stream"
    curl --request PUT \
            --url http://elastic:changeme@localhost:9200/_data_stream/$INDEX?pretty

    echo "Configured $INDEX data stream:"
    curl --request GET \
            --url http://elastic:changeme@localhost:9200/_data_stream/$INDEX?pretty


    echo "Add documents to $INDEX"

    BULK_STRING='';
    END=1080;
    for i in $(seq 1 $END);
    do
      TIMESTAMP=$(date -v -${i}0M '+%FT%T.000Z');
      VALUE=$((END-i))
      if [ $ID == '001' ] && [ $((i % 40)) -eq 0 ] ; then
        VALUE=$(( (END-i) * 10))
      fi
      DOC="
      { \"create\":{ } }\n
      { \"@timestamp\": \"${TIMESTAMP}\", \"sensor_id\": \"HAL-000001\", \"location\": \"plains\", \"temperature\": 26.7,\"humidity\": 49.9, \"counter\": ${VALUE}, \"counter_as_double\": ${VALUE} }\n
      ";
      BULK_STRING+=$DOC;
    done
    # Enable this like to copy to clipboard the bulk string to try it out in DevTools
    # echo -e $BULK_STRING | pbcopy
    curl --silent --request PUT \
            --url http://elastic:changeme@localhost:9200/$INDEX/_bulk?pretty \
            --header 'Content-Type: application/json' \
            --data "
        ${BULK_STRING}
" > /dev/null
done
