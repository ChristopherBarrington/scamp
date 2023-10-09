#! bash

# rename any gene_biotype keys to gene_type
sed 's/ gene_biotype / gene_type /' features.gtf > parsed_features.gtf

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

# create the index
cellranger-arc mkref \\
	--config config \\
	--nthreads ${task.cpus} \\
	--memgb ${task.memory.toGiga()}

# write parameters to a (yaml) file
cat <<-END_TASK > task.yaml
"${task.process}":
    ${task.index}:
        ext:
            mkref: ${mkref_args}
        params:
            organism: $organism
            assembly: $assembly
            assembly_fasta: `pwd`/assembly.fasta
            features_gtf: `pwd`/parsed_features.gtf
        task:
            work_dir: `pwd`
        versions:
            cell ranger arc: `cellranger-arc --version | sed 's/cellranger-arc cellranger-arc-//'`
END_TASK
