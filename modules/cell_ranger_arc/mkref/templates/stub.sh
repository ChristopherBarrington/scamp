#! bash

touch {task,versions}.yaml
mkdir --parents $assembly

# reformat non-nuclear contigs
NON_NUCLEAR_CONTIGS=`echo -n $non_nuclear_contigs | sed --regexp-extended 's/\\[|,|\\]//g' | jq -R -s -c 'split(" ")'`

# write the json-ish config file
cat <<-CONFIG > config
{
    organism: "$organism"
    genome: ["$assembly"]
    input_fasta: ["assembly.fasta"]
    input_gtf: ["features.gtf"]
    input_motifs: "motifs.txt"
    non_nuclear_contigs: \${NON_NUCLEAR_CONTIGS}
}
CONFIG
