# kibana_debug_utils
A set of bash utilities to quickly setup or debug things in Kibana

## Scripts available

### `untilfails.sh`

Repeat the same command over and over until it fails. Useful for flaky tests that randomly fails.

**Usage**:
```sh
./untilfails.sh <script_with_args>
```

**Examples**:

This script will run over and over the same functional test until it fails

```sh
./path/to/untilfails.sh node scripts/functional_test_runner.js --config ... --grep "some test" --bail
```

### `many_fields_index.sh`

Generates N indexes with M fields each.
**Note**: the script will delete existing indexes that match the same name pattern, so be careful when using it.
The index name pattern used in this script is the following: `many.fields-N` where `N` is the number of the index starting from 1.

Available options:

* `f`     Set the number of fields to configure on the index. Default to 9999
* `i`     Number of index to create. Default to 1
* `t`     Flag to add a @timestamp field. Default true
* `o`     Flag to add an offset to each field name. Default to 0
* `d`     Number of documents to add for each index. Default to 2. Do not abuse this as the process can get quite slow with many fields.
* `u`     The url to use for the elasticsearch node. Default to "localhost:9200".
* `p`     The prefix name for the field. Default to "field".
* `h`     Print the elp."

**Usage**:
```sh
./many_fields_index.sh [-f|i|t|o|d|h|u|p]
```

**Examples**:

This script will generate 5 indexes with 1000 fields each.

```sh
./many_fields_index.sh -f 1000 -i 5

f = 1000
i = 5
About to create:
* indexes: 5
* fields: 1000
* documents: 2
* with timestamp: 1
* with offset: 0
* with prefix: field

Connecting to localhost:9200

DELETE index many.fields-1
CREATE index and mapping for many.fields-1
UPDATE add documents to many.fields-1
	 > Documents are going to use UTC time
Loading: 100%
DELETE index many.fields-2
CREATE index and mapping for many.fields-2
UPDATE add documents to many.fields-2
	 > Documents are going to use UTC time
Loading: 100%
DELETE index many.fields-3
CREATE index and mapping for many.fields-3
UPDATE add documents to many.fields-3
	 > Documents are going to use UTC time
Loading: 100%
DELETE index many.fields-4
CREATE index and mapping for many.fields-4
UPDATE add documents to many.fields-4
	 > Documents are going to use UTC time
Loading: 100%
DELETE index many.fields-5
CREATE index and mapping for many.fields-5
UPDATE add documents to many.fields-5
	 > Documents are going to use UTC time
Loading: 100%
```

### `tsdb.sh`

Useful script to quickly generate TSDB data streams.
**Note**: the script will delete existing indexes that match the same name, so be careful when using it.
The index names used in this script are the following: `tsdb_index_001` and `tsdb_other_index_001`.

**Usage**:

```sh
./tsdb.sh
```


