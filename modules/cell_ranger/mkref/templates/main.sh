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

# write task information to a (yaml) file
cat <<-END_TASK > task.yaml
"${task.process}":
    ${task.index}:
        ext:
            mkref: ${mkref_args}
        params:
            assembly: $assembly
            assembly_fasta: `pwd`/assembly.fasta
            features_gtf: `pwd`/parsed_features.gtf
        task:
            work_dir: `pwd`
        versions:
            cell ranger: `cellranger --version | sed 's/cellranger cellranger-//'`
END_TASK
