#! bash

# rename any gene_biotype keys to gene_type
sed 's/ gene_biotype / gene_type /' features.gtf > parsed_features.gtf

# create the index
cellranger mkref $mkref_args \\
    --genome $assembly \\
    --fasta assembly.fasta \\
    --genes parsed_features.gtf \\
	--nthreads ${task.cpus} \\
	--memgb ${task.memory.toGiga()}

# write software versions used in this module
cat <<-END_VERSIONS > versions.yaml
"${task.process}":
    cell ranger: `cellranger --version | cut -f2 -d' ' | sed 's/cellranger cellranger-//'`
END_VERSIONS

# write task information to a (yaml) file
cat <<-END_TASK > task.yaml
"${task.process}":
    assembly: $assembly
    assembly_fasta: `pwd`/assembly.fasta
    features_gtf: `pwd`/parsed_features.gtf
    task_index: ${task.index}
    ext:
        mkref: ${mkref_args}
    versions:
        cell ranger: `cellranger --version | sed 's/cellranger cellranger-//'`
    work_dir: `pwd`
END_TASK
