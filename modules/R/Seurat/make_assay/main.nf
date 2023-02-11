process make_assay {
	tag "$tag"

	cpus 1
	memory '16GB'
	time '1h'

	input:
		val uid
		val tag
		val feature_identifier
		val feature_type
		path 'inputs'

	output:
		val uid, emit: uid
		path 'task.yaml', emit: task
		path 'versions.yaml', emit: versions
		path 'assay.rds', emit: assay
		path 'features.rds', emit: features

	script:
		output_assay = 'assay.rds'
		output_features = 'features.rds'
		template workflow.stubRun ? 'stub.sh' : 'main.Rscript'
}
