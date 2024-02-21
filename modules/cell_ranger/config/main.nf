process make_input_csv {
	cpus 1
	memory '1G'
	time '10m'

	input:
		val opt
		val type
		val library_ids	
		val sample_ids
		val descriptions
		val barcodes
		val feature_types
		path 'fastq_path_?'
		path 'index'
		path 'index_vdj'
		path 'probe_set.csv'
		path 'adt_set.csv'
		path 'hto_set.csv'

	output:
		val opt, emit: opt
		path 'input.csv', emit: input_csv
		path 'features.csv', emit: features_csv, optional: true

	script:
		barcodes = barcodes.collect{[it].flatten().join('|')}
		barcodes_regex = barcodes.join('|')
		library_ids_regex = library_ids.join('|')
		sample_types = [[feature_types].flatten(), [library_ids].flatten()].transpose().collect{it.join(',')}.join('\n')
		sample_barcodes = [sample_ids, barcodes, descriptions].transpose().collect{it.join(',')}.join('\n')

		fastq_files_regex = '(.*)_S[0-9]+_L[0-9]+_R1_001.fastq.gz'
		gene_expression_section_params = task.ext.gene_expression_section ?: ''
		vdj_section_params = task.ext.vdj_section ?: ''
		feature_section_params = task.ext.feature_section ?: ''
		find_fastqs_params = task.ext.find_fastqs ?: ''

		// type = type.split('-').sort().join('-')
		// type = "main"
		// switch(type) {
		//     default: template type + '.sh'
		// }

		template 'main.sh'
}
