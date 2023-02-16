process count {
	tag "$tag"

	cpus 8
	memory '64GB'
	time '3d'

	input:
		val metadata
		val tag
		val output_directory
		val samples
		val additional_arguments
		path 'index_path'
		file 'all_libraries.csv'

	output:
		val metadata, emit: metadata
    path 'task.yaml', emit: task
    path 'versions.yaml', emit: versions
		path 'libraries.csv', emit: libraries
    path "$output_directory/outs", emit: quantification_path

	script:
		samples_regex = samples.join('|')
		template workflow.stubRun ? 'stub.sh' : 'main.sh'
}
