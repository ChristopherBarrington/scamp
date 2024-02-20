process count {
	cpus 16
	memory '64GB'
	time '1d'

	input:
		val opt
		val output_dir
		val dataset_ids
		path 'config.csv'

	output:
		val opt, emit: opt
		path 'task.yaml', emit: task
		path "$output_dir/outs/config.csv", emit: config_csv
		path "$output_dir/outs/multi", emit: multi_quantification_path
		path "$output_dir/outs/per_sample_outs/*", emit: per_sample_quantification_path

	script:
		multi_args = task.ext.multi ?: ''
		single_sample_out = dataset_ids.join('-')
		expected_datasets = dataset_ids.multiply(2).join(',')

		template workflow.stubRun ? 'stub.sh' : 'main.sh'
}
