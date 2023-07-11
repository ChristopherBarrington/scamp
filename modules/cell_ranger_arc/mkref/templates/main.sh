#! bash

# create input files
cat fasta/*.fa > assembly.fasta
cat gtf/*.gtf > features.gtf

# rename any gene_biotype keys to gene_type
sed --in-place 's/ gene_biotype / gene_type /' features.gtf

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

# create the index
cellranger-arc mkref \\
	--config config \\
	--nthreads ${task.cpus} \\
	--memgb ${task.memory.toGiga()}

# write software versions used in this module
cat <<-END_VERSIONS > versions.yaml
"${task.process}":
    cell ranger arc: `cellranger-arc --version | cut -f2 -d' ' | sed 's/cellranger-arc cellranger-arc-//'`
END_VERSIONS

# write parameters to a (yaml) file
cat <<-END_TASK > task.yaml
"${task.process}":
    organism: $organism
    assembly: $assembly
    assembly_fasta: `pwd`/assembly.fasta
    features_gtf: `pwd`/features.gtf
    task_index: ${task.index}
    ext:
        mkref: ${mkref_args}
    work_dir: `pwd`
END_TASK
