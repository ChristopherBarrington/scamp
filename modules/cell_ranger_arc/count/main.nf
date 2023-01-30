process count {
	tag "$tag"

	cpus 8
	memory '64GB'
	time '3d'

	input:
		val uid
		val tag
		val output_directory
		val samples
		val additional_arguments
		path 'index_path'
		file 'all_libraries.csv'

	output:
		val uid, emit: uid
		path 'index_path', emit: index_path
		path "$output_directory/outs", emit: quantification_path
		path 'libraries.csv', emit: libraries
		path 'versions.yaml', emit: versions

	script:
		samples_regex = samples.join('|')
		template workflow.stubRun ? 'stub.sh' : 'main.sh'
}
