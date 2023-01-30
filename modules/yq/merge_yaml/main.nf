process merge_yaml {
	cpus 1
	memory '1G'
	time '10m'

	input:
		path 'input_?.yaml'

	output:
		path 'output.yaml', emit: path

	script:
		"""
		yq eval-all '. as \$item ireduce ({}; . * \$item )' input_*.yaml > output.yaml
		"""
}
