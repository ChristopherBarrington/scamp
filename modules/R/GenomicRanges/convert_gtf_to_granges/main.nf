process convert_gtf_to_granges {
	tag "$tag"

	cpus 1
	memory '8GB'
	time '1h'

	input:
		val uid
		val tag
		val genome_name
		path gtf_file
		path fai_file

	output:
		val uid, emit: uid
		path 'task.yaml', emit: task
		path 'versions.yaml', emit: versions
		path 'granges.rds', emit: granges

	script:
		template workflow.stubRun ? 'main.Rscript' : 'main.Rscript'
}
