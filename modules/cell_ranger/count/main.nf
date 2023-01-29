process count {
	tag "$tag"

	input:
		val uid
		val tag
		val output_directory
		path 'index_path'
		val additional_arguments

	output:
		val uid, emit: uid
		path 'index_path', emit: index_path
		path "$output_directory/outs", emit: quantification_path
		path 'software_versions.yaml', emit: software_versions

	stub:
		"""
		mkdir --parents $output_directory/outs
		touch software_versions.yaml
		"""
}