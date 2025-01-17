#!/bin/bash


# Should it be time based?
# 1 = with timestamp, 0 = no timestamp
WITH_TIMESTAMP="1";

# How many field to create? @timestamp will be added as extra field if enabled
FIELDS=9999;

# How many indexes to create?
INDEXES=1;

# Should field names overlap between indexes or offset? 
# 1 = no offset, 0 = with offset
# as offset technique the ID of the index is appended to the field name:
# with offset: "field-N-ID", no offset: "field-N"
FIELDS_OFFSET="0";

# How many documents for each index?
DOCS=2;
DOCS_BATCH_LIMIT=50;

# What's the URL to connect to?
FULL_URL="localhost:9200";

# Credentials
USER="elastic";
PASSWORD="changeme";

FIELD_PREFIX="field";

SLEEP_IN_SEC=10;

################################################################################
# Help                                                                         #
################################################################################
Help()
{
   # Display Help
   echo "Script to generate N indexes with M fields"
   echo
   echo "Syntax: ./many_fields_index.sh [-f|i|t|o|d|h|u|p]"
   echo "options:"
   echo "f     Set the number of fields to configure on the index. Default to $FIELDS"
   echo "i     Number of index to create. Default to $INDEXES"
   echo "t     Flag to add a @timestamp field. Default $WITH_TIMESTAMP"
   echo "o     Flag to add an offset to each field name. Default to $FIELDS_OFFSET"
   echo "d     Number of documents to add for each index. Default to $DOCS. Do not abuse this as the process can get quite slow with many fields."
   echo "u     The url to use for the elasticsearch node. Default to $FULL_URL."
   echo "p     The prefix name for the field. Default to $FIELD_PREFIX."
   echo "h     Print this Help."
   echo
}

toBoolean()
{
    [ "$1" == "1" ]
}

while getopts "f:i:t:o:d:h:u:p:" option; do
   echo $option '=' ${OPTARG};
   case $option in
        f) FIELDS=${OPTARG};;
        i) INDEXES=${OPTARG};;
        t) WITH_TIMESTAMP=${OPTARG};;
        o) FIELDS_OFFSET=${OPTARG};;
        d) DOCS=${OPTARG};;
        u) FULL_URL=${OPTARG};;
        p) FIELD_PREFIX=${OPTARG};;
        h) # display Help
           Help
           exit;;
        \?) # incorrect option
           echo "Error: Invalid option"
           exit;;
    esac
done

# DOCS=$(( DOCS > 10 ? 10 : DOCS ))

TIMESTAMP_FLAG=$(toBoolean $WITH_TIMESTAMP)

echo -e "About to create:
* indexes: $INDEXES
* fields: $FIELDS
* documents: $DOCS
* with timestamp: $WITH_TIMESTAMP
* with offset: $FIELDS_OFFSET
* with prefix: $FIELD_PREFIX

Connecting to $FULL_URL
"

# Compute the new field limit for the index
FIELDS_LIMIT=$(( FIELDS >= 1000 ? (FIELDS + 1) : 1000 ))

for ID in $(seq 1 $INDEXES);
do
    INDEX="many.fields-$ID";

    # if  [ $((ID % 5)) -eq 0 ]
    # then
    #     echo "SLEEP ${SLEEP_IN_SEC}s"
    #     sleep $SLEEP_IN_SEC
    # fi

    OFFSET_SUFFIX="";
    if [ $FIELDS_OFFSET == "1" ];
    then
        OFFSET_SUFFIX="-$ID"
    fi

    SECONDS=0
    echo -ne "DELETE index $INDEX"
    curl -s --request DELETE --url http://$USER:$PASSWORD@$FULL_URL/$INDEX > /dev/null
    echo -e "\rDELETE index $INDEX: Took $SECONDS s"


    SECONDS=0
    echo "CREATE index and mapping for $INDEX"
    # use printf here to speedup string concatenation
    BULK_STRING=$(
        INTRO="{
        \"settings\":{
            \"index.mapping.total_fields.limit\": ${FIELDS_LIMIT}
        },
        \"mappings\": {
            \"properties\": {"
        printf %s "$INTRO"

        FIELD_MAPPING=$(
            INTRO='';
            if toBoolean $WITH_TIMESTAMP;
            then
                INTRO="
                    \"@timestamp\": {
                        \"type\": \"date\",
                        \"format\": \"strict_date_optional_time\"
                    },";
            fi

            printf %s "$INTRO"

            for i in $(seq 1 $FIELDS);
            do
                F_MAPPING="
                \"${FIELD_PREFIX}-${i}${OFFSET_SUFFIX}\": {
                ";
                VALUE="\"double\"";
                if  [ $((i % 2)) -eq 0 ]
                then
                    VALUE="\"keyword\"";
                fi
                F_MAPPING+="\"type\": $VALUE";

                if  [ $((i % 2)) -eq 1 ]
                then
                    F_MAPPING+=",\"meta\": { \"unit\": \"ms\"}";
                fi
                F_MAPPING+="}";
                if [ $i -lt $FIELDS ]
                then
                    F_MAPPING+=", ";
                fi
                printf %s "$F_MAPPING"
            done
        )


    END_FIELD_MAPPING="
        }
    }
}
"
        printf %s "$FIELD_MAPPING$END_FIELD_MAPPING"
    )
    echo -e "\tMapping creation: Took $SECONDS s"
    # echo -e $BULK_STRING
    # echo  "${BULK_STRING}"
    SECONDS=0;
    echo "${BULK_STRING}
" | curl -s --fail --show-error --request PUT \
            --url "http://$USER:$PASSWORD@$FULL_URL/$INDEX?pretty" \
            --header 'Content-Type: application/json' \
            --data-binary "@-" > /dev/null



    echo -e "\tcurl: Took $SECONDS s"
    SECONDS=0;
    echo "UPDATE add documents to $INDEX"

    if toBoolean $WITH_TIMESTAMP;
    then
        echo -e "\t > Documents are going to use UTC time";
    fi

    echo -ne "\rLoading: 0%"
    BULK_STRING=$(
        for i in $(seq 1 $DOCS);
        do
            TIMESTAMP=$(date -v -${i}0S '+%FT%T.000Z');
            DOC=$(
                INTRO="
            { \"create\":{ } }
            { ";
                printf %s "$INTRO"
                if toBoolean $WITH_TIMESTAMP;
                then
                    TS_FIELD="\"@timestamp\": \"${TIMESTAMP}\", ";
                    printf %s "$TS_FIELD"
                fi
                for j in $(seq 1 $FIELDS);
                do
                    VALUE=1
                    if  [ $((j % 2)) -eq 0 ]
                    then
                        VALUE='"a"';
                    fi
                    FIELD_VALUE="\"$FIELD_PREFIX-$j$OFFSET_SUFFIX\": ${VALUE}"
                    if [ $j -lt $FIELDS ]
                    then
                        FIELD_VALUE+=", ";
                    else
                        FIELD_VALUE+="}";
                    fi
                    printf %s "$FIELD_VALUE"
                done
            )
        printf %s "$DOC";
    
      
        if  [ $((i % DOCS_BATCH_LIMIT)) -eq 0 ]
        then
            l=$(( 100 * $i / $DOCS ))
            echo -ne "\rLoading: $l%"
        fi
        done
    )
    TEMP_SECONDS=$SECONDS
    SECONDS=0;
    if [ ! -z "$BULK_STRING" ]
    then
        echo "${BULK_STRING}
" | curl -s --fail --show-error --request PUT \
            --url "http://$USER:$PASSWORD@$FULL_URL/$INDEX/_bulk?pretty" \
            --header 'Content-Type: application/json' \
            --data-binary "@-" > /dev/null
    fi
    echo -ne "\rLoading: 100%"
    echo ""
    echo -e "\tDocuments creation: Took $TEMP_SECONDS";
    echo -e "\tcurl: Took $SECONDS s";
done
