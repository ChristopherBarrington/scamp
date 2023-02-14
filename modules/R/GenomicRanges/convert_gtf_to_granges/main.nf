process convert_gtf_to_granges {
	tag "$tag"

	cpus 1
	memory '8GB'
	time '1h'

	input:
		val metadata
		val tag
		val genome
		path gtf
		path fai

	output:
		val metadata, emit: metadata
		path 'task.yaml', emit: task
		path 'versions.yaml', emit: versions
		path 'granges.rds', emit: granges

	script:
		template workflow.stubRun ? 'stub.sh' : 'main.Rscript'
}
