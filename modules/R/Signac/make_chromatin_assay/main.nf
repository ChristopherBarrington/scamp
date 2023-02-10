process make_chromatin_assay {
	tag "$tag"

	// define resource
	cpus 1
	memory '16GB'
	time '1h'

	// define expected input channels
	input:
		val uid
		val tag
		path 'inputs'
		path 'annotations'

	// define expected output channels
	output:
		val uid, emit: uid
		path 'task.yaml', emit: task
		path 'versions.yaml', emit: versions
		path 'assay.rds', emit: assay
		path 'features.rds', emit: features

	// define additional nextflow properties to pass to the template script
	script:
		feature_type = 'Chromatin Accessibility'
		output_assay = 'assay.rds'
		output_features = 'features.rds'
		template workflow.stubRun ? 'stub.sh' : 'main.Rscript'
}
