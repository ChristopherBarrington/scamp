process process_name {
	tag "$tag"

	cpus 1
	memory '4GB'
	time '1h'

	input:
		val uid
		val tag

		val channel_1
		val channel_1

	output:
		val uid, emit: uid
		path 'task.yaml', emit: task
		path 'versions.yaml', emit: versions

		path 'output_1.rds', emit: output_1

	script:
		template workflow.stubRun ? 'stub.sh' : 'main.Rscript'
}