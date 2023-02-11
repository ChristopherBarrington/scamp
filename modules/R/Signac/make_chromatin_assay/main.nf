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
		path 'annotations.rds'
		path 'counts_matrices.rds'
		path 'quantification_path'
		val feature_type

	// define expected output channels
	output:
		val uid, emit: uid
		path 'task.yaml', emit: task
		path 'versions.yaml', emit: versions
		path 'assay.rds', emit: assay

	// define additional nextflow properties to pass to the template script
	script:
		template workflow.stubRun ? 'stub.sh' : 'main.Rscript'
}
