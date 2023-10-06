#! bash

touch {task,versions}.yaml parsed_features.gtf
mkdir --parents $assembly

# reformat non-nuclear contigs
NON_NUCLEAR_CONTIGS=`echo -n $non_nuclear_contigs | sed --regexp-extended 's/\\[|,|\\]//g' | jq -R -s -c 'split(" ")'`

# write the json-ish config file
cat <<-CONFIG > config
{
    organism: "$organism"
    genome: ["$assembly"]
    input_fasta: ["assembly.fasta"]
    input_gtf: ["parsed_features.gtf"]
    input_motifs: "motifs.txt"
    non_nuclear_contigs: \${NON_NUCLEAR_CONTIGS}
}
CONFIG

# write parameters to a (yaml) file
cat <<-END_TASK > task.yaml
"${task.process}":
    organism: $organism
    assembly: $assembly
    assembly_fasta: `pwd`/assembly.fasta
    features_gtf: `pwd`/parsed_features.gtf
    task_index: ${task.index}
    ext:
        mkref: ${mkref_args}
    versions:
    work_dir: `pwd`
END_TASK
