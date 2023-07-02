#! /bin/env bash

# write a yaml file with content defined from command line key/value pairs

# eg: write_yaml.sh "foo:bar baz" key1 value1 "key two" "value two"

# argument 1 is the root key(s), with levels separated by colons
# arguments n, n+1 are the key/value pairs to output

ROOT_KEY=$1

shift # remove the leading non key/value pairs

# define the versions' key pairs
KEYS=$(while (( "$#" )); do
	echo \"$1\":\"$2\"
	shift ; shift
done | awk --assign ORS=',' '{print}' | sed 's/,$//')

# write a yaml formatted file to stdout
NESTED_PROCESS_KEY=`sed 's/:/\"].[\"/g' <<< ${ROOT_KEY} | sed --regexp-extended 's/(.*)/["\1"]/'`
YAML_EXPRESSION=".${NESTED_PROCESS_KEY}={${KEYS}}"
yq --null-input "$YAML_EXPRESSION"
