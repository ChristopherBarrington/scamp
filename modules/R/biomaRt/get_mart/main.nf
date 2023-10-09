process get_mart {
	tag "$organism release $release"

	cpus 1
	memory '2GB'
	time '10m'

	input:
		val opt
		val organism
		val release

	output:
		val opt, emit: opt
		path 'task.yaml', emit: task
		path 'mart.rds', emit: mart

	script:
		template workflow.stubRun ? 'stub.sh' : 'main.Rscript'
}
