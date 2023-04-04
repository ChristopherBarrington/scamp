#! /bin/env bash

# get comma-separated list of input directories to find fastq files
FASTQ_PATHS=`find -L fastq_path_* -mindepth 1 -maxdepth 1 -name "${sample}_S*_L*_R1_*.fastq.gz" -printf '%h\\n' | \
	sort | \
	uniq | \
	awk '{printf "%s%s", sep, \$1 ; sep=","} END{print ""}'`

# run cell ranger count
cellranger count \
	--id=output \
	--transcriptome=`realpath index_path` \
	--fastqs=\${FASTQ_PATHS} \
	--sample=$sample \
	--jobmode=local --localcores=${task.cpus} --localmem=${task.memory.toGiga()} \
	--disable-ui

# write software versions used in this module
cat <<-END_VERSIONS > versions.yaml
"${task.process}":
    cell ranger: `cellranger --version | sed 's/cellranger cellranger-//'`
END_VERSIONS

# write parameters to a (yaml) file
cat <<-END_TASK > task.yaml
"${task.process}":
    sample: $sample
    index_path: `realpath index_path`
    task_index: ${task.index}
END_TASK
