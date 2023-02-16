process make_libraries_csv {
	cpus 1
	memory '1G'
	time '10m'

	input:
		val metadata
		path 'fastq_path_?'
		val fastq_files_regex
		val samples
		val feature_types

	output:
		val metadata, emit: metadata
		path 'libraries.csv', emit: path

	script:
		sample_types = [feature_types, samples].transpose().collect{it.join(',')}.join('\n')
		template 'main.sh'
}