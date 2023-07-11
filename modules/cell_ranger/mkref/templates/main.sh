#! bash

# get software version(s)
VERSION=`cellranger --version | cut -f2 -d' ' | sed 's/cellranger cellranger-//'`

# create input files
cat $path_to_fastas/*.fa > assembly.fasta
cat $path_to_gtfs/*.gtf > features.gtf

# rename any gene_biotype keys to gene_type
sed --in-place 's/ gene_biotype / gene_type /' features.gtf

# create the index
cellranger mkref $mkref_args \\
    --genome $assembly \\
    --fasta assembly.fasta \\
    --genes features.gtf \\
	--nthreads ${task.cpus} \\
	--memgb ${task.memory.toGiga()}

# write software versions used in this module
cat <<-END_VERSIONS > versions.yaml
"${task.process}":
    cell ranger: \${VERSION}
END_VERSIONS
