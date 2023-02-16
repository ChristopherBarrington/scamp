#! /bin/env bash

# get software version(s)
VERSION=`cellranger-arc --version | cut -f2 -d' ' | sed 's/cellranger-arc-//'`

# create input files
cat $path_to_fastas/*.fa > assembly.fasta
cat $path_to_gtfs/*.gtf > features.gtf

#
# todo: filter the gtf
# ! make sure gene_type not gene_biotype !
#

# reformat non-nuclear contigs
NON_NUCLEAR_CONTIGS=`echo -n $non_nuclear_contigs | sed --regexp-extended 's/\\[|,|\\]//g' | jq -R -s -c 'split(\" \")'`

# write the json-ish config file
echo \"\"\"{
    organism: \\"$organism\\"
    genome: [\\"$assembly\\"]
    input_fasta: [\\"assembly.fasta\\"]
    input_gtf: [\\"features.gtf\\"]
    input_motifs: \\"motifs.txt\\"
    non_nuclear_contigs: \$NON_NUCLEAR_CONTIGS
}\"\"\" > config

# create the index
cellranger-arc mkref \
	--config config \
	--nthreads ${task.cpus} \
	--memgb ${task.memory.toGiga()} \
	--ref-version \${VERSION}

# write software versions used in this module
cat <<-END_VERSIONS > versions.yaml
"${task.process}":
    cell ranger arc: \${VERSION}
END_VERSIONS
