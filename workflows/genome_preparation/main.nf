// -------------------------------------------------------------------------------------------------
// import any java/groovy libraries as required
// -------------------------------------------------------------------------------------------------

import java.nio.file.Paths

// -------------------------------------------------------------------------------------------------
// specify modules relevant to this workflow
// -------------------------------------------------------------------------------------------------

include { cat as cat_fastas } from '../../modules/cat'
include { cat as cat_gtfs }   from '../../modules/cat'

include { faidx } from '../../modules/samtools/faidx'

include { check_for_matching_key_values }     from '../../utilities/check_for_matching_key_values'
include { concat_workflow_emissions }         from '../../utilities/concat_workflow_emissions'
include { concatenate_maps_list }             from '../../utilities/concatenate_maps_list'
include { make_map }                          from '../../utilities/make_map'
include { merge_metadata_and_process_output } from '../../utilities/merge_metadata_and_process_output'
include { merge_process_emissions }           from '../../utilities/merge_process_emissions'
include { rename_map_keys }                   from '../../utilities/rename_map_keys'

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

		// -------------------------------------------------------------------------------------------------
		// merge genome gtf files, if provided by `gtf path`
		// -------------------------------------------------------------------------------------------------

		// branch parameters into multiple channels according to the 'quantification method' key
		parameters
			.map{it.get('genome parameters').subMap(['key', 'id', 'gtf file', 'gtf path'])}
			.unique()
			.branch{
				def has_gtf_file = it.containsKey('gtf file')
				def has_gtf_path = it.containsKey('gtf path')
				to_merge: has_gtf_file == false & has_gtf_path == true
				to_skip: has_gtf_file == true | has_gtf_path == false}
			.set{gtf_paths}

		gtf_paths.to_merge.dump(tag: 'genome_preparation:gtf_paths.to_merge', pretty: true)
		gtf_paths.to_skip.dump(tag: 'genome_preparation:gtf_paths.to_skip', pretty: true)

		// make channels of parameters for genomes that need indexes to be created
		input_paths  = gtf_paths.to_merge.map{it.get('gtf path')}
		output_files = fasta_paths.to_merge.map{it.get('id') + '.gtf'}

		// create cell ranger arc indexes
		cat_gtfs(gtf_paths.to_merge, input_paths, output_files)

		// make a channel of newly created genome indexes, each defined in a map
		merge_process_emissions(cat_gtfs, ['opt', 'path'])
			.map{rename_map_keys(it, 'path', 'gtf file')}
			.map{merge_metadata_and_process_output(it)}
			.concat(gtf_paths.to_skip)
			.map{it.subMap(['key', 'gtf file'])}
			.dump(tag: 'genome_preparation:gtf_files', pretty: true)
			.set{gtf_files}

		// -------------------------------------------------------------------------------------------------
		// make GRanges objects for gene annotations of the genomes
		// -------------------------------------------------------------------------------------------------

		// merge the fasta and gtf process outputs
		indexed_fasta_files
			.combine(gtf_files)
			.filter{check_for_matching_key_values(it, ['key'])}
			.map{concatenate_maps_list(it)}
			.dump(tag: 'genome_preparation:fasta_and_gtf_files', pretty: true)
		 	.set{fasta_and_gtf_files}

		// create the channels for the process to make GRanges objects
		fasta_and_gtf_files
			.map{it.subMap(['key', 'gtf file', 'fasta index file'])}
			.dump(tag: 'genome_preparation:gtf_files_to_convert_to_granges', pretty: true)
			.set{gtf_files_to_convert_to_granges}

		genomes   = gtf_files_to_convert_to_granges.map{it.get('key')}
		gtf_files = gtf_files_to_convert_to_granges.map{it.get('gtf file')}
		fai_files = gtf_files_to_convert_to_granges.map{it.get('fasta index file')}

		// make the granges rds files from gtf files
		convert_gtf_to_granges(gtf_files_to_convert_to_granges, genomes, gtf_files, fai_files)

		// make a channel of newly created GRanges rds files
		merge_process_emissions(convert_gtf_to_granges, ['opt', 'granges'])
			.map{rename_map_keys(it, 'granges', 'granges file')}
			.map{merge_metadata_and_process_output(it).subMap(['key','granges file'])}
			.dump(tag: 'genome_preparation:granges_files', pretty: true)
			.set{granges_files}

}
