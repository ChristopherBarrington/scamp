// -------------------------------------------------------------------------------------------------
// specify modules relevant to this workflow
// -------------------------------------------------------------------------------------------------

include { cat as cat_fastas } from '../../modules/tools/cat'
include { cat as cat_gtfs }   from '../../modules/tools/cat'

include { faidx } from '../../modules/samtools/faidx'

include { convert_gtf_to_granges } from '../../modules/R/GenomicRanges/convert_gtf_to_granges'
include { get_mart }               from '../../modules/R/biomaRt/get_mart'

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
		// select the genome parameters stanza from dataset parameters
		// -------------------------------------------------------------------------------------------------

		parameters
			.map{it.get('genome parameters')}
			.unique()
			.dump(tag: 'genome_preparation:genome_parameters', pretty: true)
			.set{genome_parameters}

		// -------------------------------------------------------------------------------------------------
		// merge genome fasta files
		// -------------------------------------------------------------------------------------------------

		// branch parameters into multiple channels using key(s)
		genome_parameters
			.map{it.subMap(['key', 'id', 'fasta file', 'fasta path', 'fasta index file'])}
			.branch{
				def has_fasta_file = it.containsKey('fasta file')
				def has_fasta_path = it.containsKey('fasta path')
				to_merge: !has_fasta_file & has_fasta_path
				to_skip: has_fasta_file | !has_fasta_path}
			.set{fasta_paths}

		fasta_paths.to_merge.dump(tag: 'genome_preparation:fasta_paths.to_merge', pretty: true)
		fasta_paths.to_skip.dump(tag: 'genome_preparation:fasta_paths.to_skip', pretty: true)

		// make channels of parameters
		input_paths = fasta_paths.to_merge.map{it.get('fasta path')}
		output_files = fasta_paths.to_merge.map{it.get('id') + '.fa'}

		// run the process
		cat_fastas(fasta_paths.to_merge, input_paths, output_files)

		// make a channel of newly created parameters
		merge_process_emissions(cat_fastas, ['opt', 'path'])
			.map{rename_map_keys(it, 'path', 'fasta file')}
			.map{merge_metadata_and_process_output(it)}
			.concat(fasta_paths.to_skip)
			.map{it.subMap(['key', 'id', 'fasta file'])}
			.dump(tag: 'genome_preparation:fasta_files', pretty: true)
			.set{fasta_files}

		// -------------------------------------------------------------------------------------------------
		// make fai for genomes
		// -------------------------------------------------------------------------------------------------

		// branch parameters into multiple channels using key(s)
		fasta_files
			.branch{
				def has_fasta_file = it.containsKey('fasta file')
				def has_fasta_index_file = it.containsKey('fasta index file')
				to_make: has_fasta_file & !has_fasta_index_file
				to_skip: !has_fasta_file | has_fasta_index_file}
			.set{fasta_index_files}

		fasta_index_files.to_make.dump(tag: 'genome_preparation:fasta_index_files.to_make', pretty: true)
		fasta_index_files.to_skip.dump(tag: 'genome_preparation:fasta_index_files.to_skip', pretty: true)

		// make channels of parameters
		input_files = fasta_index_files.to_make.map{it.get('fasta file')}

		// run the process
		faidx(fasta_index_files.to_make, input_files)

		// make a channel of newly created parameters
		merge_process_emissions(faidx, ['opt', 'path'])
			.map{rename_map_keys(it, 'path', 'fasta index file')}
			.map{merge_metadata_and_process_output(it)}
			.concat(fasta_index_files.to_skip)
			.map{it.subMap(['key', 'id', 'fasta index file'])}
			.dump(tag: 'genome_preparation:indexed_fasta_files', pretty: true)
			.set{indexed_fasta_files}

		// -------------------------------------------------------------------------------------------------
		// merge genome gtf files, if provided by `gtf path`
		// -------------------------------------------------------------------------------------------------

		// branch parameters into multiple channels using key(s)
		genome_parameters
			.map{it.subMap(['key', 'id', 'gtf file', 'gtf path'])}
			.branch{
				def has_gtf_file = it.containsKey('gtf file')
				def has_gtf_path = it.containsKey('gtf path')
				to_merge: !has_gtf_file & has_gtf_path
				to_skip: has_gtf_file | !has_gtf_path}
			.set{gtf_paths}

		gtf_paths.to_merge.dump(tag: 'genome_preparation:gtf_paths.to_merge', pretty: true)
		gtf_paths.to_skip.dump(tag: 'genome_preparation:gtf_paths.to_skip', pretty: true)

		// make channels of parameters
		input_paths  = gtf_paths.to_merge.map{it.get('gtf path')}
		output_files = fasta_paths.to_merge.map{it.get('id') + '.gtf'}

		// run the process
		cat_gtfs(gtf_paths.to_merge, input_paths, output_files)

		// make a channel of newly created parameters
		merge_process_emissions(cat_gtfs, ['opt', 'path'])
			.map{rename_map_keys(it, 'path', 'gtf file')}
			.map{merge_metadata_and_process_output(it)}
			.concat(gtf_paths.to_skip)
			.map{it.subMap(['key', 'id', 'gtf file'])}
			.dump(tag: 'genome_preparation:gtf_files', pretty: true)
			.set{gtf_files}

		// -------------------------------------------------------------------------------------------------
		// make GRanges objects for gene annotations of the genomes
		// -------------------------------------------------------------------------------------------------

		// merge the fasta and gtf process outputs
		// branch parameters into multiple channels using key(s)
		indexed_fasta_files
			.combine(gtf_files)
			.filter{check_for_matching_key_values(it, ['key'])}
			.map{concatenate_maps_list(it)}
			.map{it.subMap(['key', 'id', 'gtf file', 'fasta index file'])}
			.branch{
				def has_fasta_index_file = it.containsKey('fasta index file')
				def has_gtf_file = it.containsKey('gtf file')
				to_make: has_fasta_index_file & has_gtf_file
				to_skip: !has_fasta_index_file | !has_gtf_file}
		 	.set{granges_files}

		granges_files.to_make.dump(tag: 'genome_preparation:granges_files.to_make', pretty: true)
		granges_files.to_skip.dump(tag: 'genome_preparation:granges_files.to_skip', pretty: true)

		// make channels of parameters
		genomes = granges_files.to_make.map{it.get('id')}
		gtfs    = granges_files.to_make.map{it.get('gtf file')}
		fais    = granges_files.to_make.map{it.get('fasta index file')}

		// run the process
		convert_gtf_to_granges(granges_files.to_make, genomes, gtfs, fais)

		// make a channel of newly created parameters
		merge_process_emissions(convert_gtf_to_granges, ['opt', 'granges'])
			.map{merge_metadata_and_process_output(it)}
			.concat(granges_files.to_skip)
			.map{it.subMap(['key', 'id', 'granges'])}
			.dump(tag: 'genome_preparation:granges_files', pretty: true)
			.set{granges_files}

		// -------------------------------------------------------------------------------------------------
		// make a biomaRt object for the genome
		// -------------------------------------------------------------------------------------------------

		// create the channels for the process to make biomaRt objects
		genome_parameters
			.map{it.subMap(['key', 'id', 'organism', 'ensembl release'])}
			.dump(tag: 'genome_preparation:biomart_connections_to_make', pretty: true)
			.set{biomart_connections_to_make}

		organisms        = biomart_connections_to_make.map{it.get('organism')}
		ensembl_releases = biomart_connections_to_make.map{it.get('ensembl release')}

		// make the mart rds files
		get_mart(biomart_connections_to_make, organisms, ensembl_releases)

		// make a channel of newly created GRanges rds files
		merge_process_emissions(get_mart, ['opt', 'mart'])
			.map{rename_map_keys(it, 'mart', 'biomart connection')}
			.map{merge_metadata_and_process_output(it)}
			.map{it.subMap(['key', 'id', 'biomart connection'])}
			.dump(tag: 'genome_preparation:mart_files', pretty: true)
			.set{mart_files}

		// -------------------------------------------------------------------------------------------------
		// join any/all information back onto the parameters ready to emit
		// -------------------------------------------------------------------------------------------------

		fasta_files
			.combine(indexed_fasta_files)
			.combine(gtf_files)
			.combine(granges_files)
			.combine(mart_files)
			.filter{check_for_matching_key_values(it, ['id'])}
			.map{concatenate_maps_list(it)}
			.combine(parameters)
			.filter{it.first().get('key') == it.last().get('genome')}
			.map{it.last().findAll{it.key != 'genome parameters'} + ['genome parameters': it.last().get('genome parameters') + it.first()]}
			.dump(tag: 'genome_preparation:final_results', pretty: true)
			.set{final_results}

	emit:
		result = final_results
}
