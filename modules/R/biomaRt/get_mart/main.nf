process get_mart {
	tag "$tag"

	cpus 1
	memory '2GB'
	time '10m'

	input:
		val opt
		val tag
		val organism
		val release

	output:
		val opt, emit: opt
		path 'task.yaml', emit: task
		path 'versions.yaml', emit: versions
		path 'mart.rds', emit: mart

	script:
		template workflow.stubRun ? 'stub.sh' : 'main.Rscript'
}
