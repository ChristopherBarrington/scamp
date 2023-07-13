// -------------------------------------------------------------------------------------------------
// specify modules relevant to this workflow
// -------------------------------------------------------------------------------------------------

include { cat as cat_fastas } from '../../modules/cat'
// -------------------------------------------------------------------------------------------------
// define the workflow
// -------------------------------------------------------------------------------------------------

workflow genome_preparation {

	take:
		parameters

	main:
		// -------------------------------------------------------------------------------------------------
		// merge genome fasta files
		// -------------------------------------------------------------------------------------------------

		// branch parameters into multiple channels according to the 'fasta file' and 'fasta path' keys
		// if 'fasta file' is provided, don't merge fasta files in 'fasta path'
		parameters
			.map{it.get('genome parameters').subMap(['key', 'id', 'fasta file', 'fasta path', 'fasta index file'])}
			.unique()
			.branch{
				def has_fasta_file = it.containsKey('fasta file')
				def has_fasta_path = it.containsKey('fasta path')
				to_merge: has_fasta_file == false & has_fasta_path == true
				to_skip: has_fasta_file == true | has_fasta_path == false}
			.set{fasta_paths}

		fasta_paths.to_merge.dump(tag: 'genome_preparation:fasta_paths.to_merge', pretty: true)
		fasta_paths.to_skip.dump(tag: 'genome_preparation:fasta_paths.to_skip', pretty: true)

		// make channels of parameters for genomes that need indexes to be created
		input_paths = fasta_paths.to_merge.map{it.get('fasta path')}
		output_files = fasta_paths.to_merge.map{it.get('id') + '.fa'}

		// create cell ranger arc indexes
		cat_fastas(fasta_paths.to_merge, input_paths, output_files)

		// make a channel of newly created genome indexes, each defined in a map
		merge_process_emissions(cat_fastas, ['opt', 'path'])
			.map{rename_map_keys(it, 'path', 'fasta file')}
			.map{merge_metadata_and_process_output(it)}
			.concat(fasta_paths.to_skip)
			.dump(tag: 'genome_preparation:fasta_files', pretty: true)
			.set{fasta_files}

		// -------------------------------------------------------------------------------------------------
		// make fai for genomes
		// -------------------------------------------------------------------------------------------------

		// branch parameters into multiple channels according to the 'fasta index file' key
		fasta_files
			.branch{
				def has_fasta_index_file = it.containsKey('fasta index file')
				missing: has_fasta_index_file == false
				provided: has_fasta_index_file == true}
			.set{fasta_index_files}

		fasta_index_files.missing.dump(tag: 'genome_preparation:fasta_index_files.missing', pretty: true)
		fasta_index_files.provided.dump(tag: 'genome_preparation:fasta_index_files.provided', pretty: true)

		// make channels of parameters for genomes that need indexes to be created
		input_files = fasta_index_files.missing.map{it.get('fasta file')}

		// create cell ranger arc indexes
		faidx(fasta_paths.to_merge, input_files)

		// make a channel of newly created genome indexes, each defined in a map
		merge_process_emissions(faidx, ['opt', 'path'])
			.map{rename_map_keys(it, 'path', 'fasta index file')}
			.map{merge_metadata_and_process_output(it)}
			.concat(fasta_index_files.provided)
			.map{it.subMap(['key', 'fasta index file'])}
			.dump(tag: 'genome_preparation:indexed_fasta_files', pretty: true)
			.set{indexed_fasta_files}

}
