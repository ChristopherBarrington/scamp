process merge_yaml {
	cpus 1
	memory '1G'
	time '10m'

	input:
		path 'input_software_versions_?.yaml'

	output:
		path 'software_versions.yaml', emit: path

	script:
		"""
		yq eval-all '. as \$item ireduce ({}; . * \$item )' input_software_versions_*.yaml > software_versions.yaml
		"""
}
