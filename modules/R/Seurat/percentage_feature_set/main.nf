process percentage_feature_set {
	tag "$tag"

	cpus 1
	memory '4GB'
	time '15m'

	input:
		val opt
		val tag
		val assay
		path 'feature_sets.yaml'
		path 'input_seurat.rds'

	output:
		val opt, emit: opt
		path 'task.yaml', emit: task
		path 'versions.yaml', emit: versions
		path 'seurat.rds', emit: seurat

	script:
		template workflow.stubRun ? 'stub.sh' : 'main.Rscript'
}
