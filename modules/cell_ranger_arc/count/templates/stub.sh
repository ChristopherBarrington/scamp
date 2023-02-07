#! /bin/env bash

# get software version(s)
VERSION=`cellranger-arc --version | cut -f2 -d' ' | sed 's/cellranger-arc-//'`

# filter the complete libraries file for the samples in this dataset
awk --assign FS=',' 'NR==1{print} ; \$2~/^($samples_regex)\$/{print}' all_libraries.csv > libraries.csv

# run cell ranger arc count
# cellranger-arc count ...
mkdir --parents $output_directory/outs

# write software versions used in this module
cat <<-END_VERSIONS > versions.yaml
"${task.process}":
    cell ranger arc: \${VERSION}
END_VERSIONS
