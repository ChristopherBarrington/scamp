process count {
	tag "$tag"

	cpus 16
	memory '64GB'
	time '3d'

	input:
		val opt
		val tag
		val name
		val id
		val sample
		path 'fastq_path_?'
		path 'index_path'

	output:
		val opt, emit: opt
		path 'task.yaml', emit: task
		path 'versions.yaml', emit: versions
		path "$id", emit: quantification_path

	script:
		template workflow.stubRun ? 'stub.sh' : 'main.sh'
}
