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
			.first()
			.map{it.get('genome parameters')}
			.dump(tag: 'genome_preparation:genome_parameters', pretty: true)
			.set{genome_parameters}

		// -------------------------------------------------------------------------------------------------
		// merge genome fasta files
		// -------------------------------------------------------------------------------------------------

		// branch parameters into multiple channels using key(s)
		genome_parameters
			.branch{
				def has_fasta_file = it.containsKey('fasta file')
				def has_fasta_path = it.containsKey('fasta path')
				to_make: !has_fasta_file & has_fasta_path
				to_skip: has_fasta_file | !has_fasta_path}
			.set{fasta_files}

		fasta_files.to_make.dump(tag: 'genome_preparation:fasta_files.to_make', pretty: true)
		fasta_files.to_skip.dump(tag: 'genome_preparation:fasta_files.to_skip', pretty: true)

		// make channels of parameters
		fasta_paths  = fasta_files.to_make.map{it.get('fasta path')}
		output_files = fasta_files.to_make.map{it.get('id') + '.fa'}

		// run the process
		cat_fastas([:], fasta_paths, output_files)

		// make a channel of newly created parameters
		merge_process_emissions(cat_fastas, ['opt', 'path'])
			.map{rename_map_keys(it, 'path', 'fasta file')}
			.map{merge_metadata_and_process_output(it)}
			.concat(fasta_files.to_skip)
			.merge(genome_parameters)
			.map{it.last() + it.first()}
			.dump(tag: 'genome_preparation:fasta_files', pretty: true)
			.set{genome_parameters}

		// -------------------------------------------------------------------------------------------------
		// make fai for genomes
		// -------------------------------------------------------------------------------------------------

		// branch parameters into multiple channels using key(s)
		genome_parameters
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
		faidx([:], input_files)

		// make a channel of newly created parameters
		merge_process_emissions(faidx, ['opt', 'path'])
			.map{rename_map_keys(it, 'path', 'fasta index file')}
			.map{merge_metadata_and_process_output(it)}
			.concat(fasta_index_files.to_skip)
			.merge(genome_parameters)
			.map{it.last() + it.first()}
			.dump(tag: 'genome_preparation:fasta_index_files', pretty: true)
			.set{genome_parameters}

		// -------------------------------------------------------------------------------------------------
		// merge genome gtf files, if provided by `gtf path`
		// -------------------------------------------------------------------------------------------------

		// branch parameters into multiple channels using key(s)
		genome_parameters
			.branch{
				def has_gtf_file = it.containsKey('gtf file')
				def has_gtf_path = it.containsKey('gtf path')
				to_make: !has_gtf_file & has_gtf_path
				to_skip: has_gtf_file | !has_gtf_path}
			.set{gtf_files}

		gtf_files.to_make.dump(tag: 'genome_preparation:gtf_files.to_make', pretty: true)
		gtf_files.to_skip.dump(tag: 'genome_preparation:gtf_files.to_skip', pretty: true)

		// make channels of parameters
		gtf_paths    = gtf_files.to_make.map{it.get('gtf path')}
		output_files = gtf_files.to_make.map{it.get('id') + '.gtf'}

		// run the process
		cat_gtfs([:], gtf_paths, output_files)

		// make a channel of newly created parameters
		merge_process_emissions(cat_gtfs, ['opt', 'path'])
			.map{rename_map_keys(it, 'path', 'gtf file')}
			.map{merge_metadata_and_process_output(it)}
			.concat(gtf_files.to_skip)
			.merge(genome_parameters)
			.map{it.last() + it.first()}
			.dump(tag: 'genome_preparation:gtf_files', pretty: true)
			.set{genome_parameters}

		// -------------------------------------------------------------------------------------------------
		// make GRanges objects for gene annotations of the genomes
		// -------------------------------------------------------------------------------------------------

		// branch parameters into multiple channels using key(s)
		genome_parameters
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
		convert_gtf_to_granges([:], genomes, gtfs, fais)

		// make a channel of newly created parameters
		merge_process_emissions(convert_gtf_to_granges, ['opt', 'granges'])
			.map{merge_metadata_and_process_output(it)}
			.concat(granges_files.to_skip)
			.merge(genome_parameters)
			.map{it.last() + it.first()}
			.dump(tag: 'genome_preparation:granges_files', pretty: true)
			.set{genome_parameters}

		// -------------------------------------------------------------------------------------------------
		// make a biomaRt object for the genome
		// -------------------------------------------------------------------------------------------------

		// // branch parameters into multiple channels using key(s)
		genome_parameters
			.branch{
				def has_ensembl_release = it.containsKey('ensembl release')
				to_make: has_ensembl_release
				to_skip: !has_ensembl_release}
			.set{mart_files}

		mart_files.to_make.dump(tag: 'genome_preparation:mart_files.to_make', pretty: true)
		mart_files.to_skip.dump(tag: 'genome_preparation:mart_files.to_skip', pretty: true)

		// make channels of parameters
		organisms        = mart_files.to_make.map{it.get('organism')}
		ensembl_releases = mart_files.to_make.map{it.get('ensembl release')}

		// run the process
		get_mart([:], organisms, ensembl_releases)

		// make a channel of newly created parameters
		merge_process_emissions(get_mart, ['opt', 'mart'])
			.map{rename_map_keys(it, 'mart', 'biomart connection')}
			.map{merge_metadata_and_process_output(it)}
			.concat(mart_files.to_skip)
			.merge(genome_parameters)
			.map{it.last() + it.first()}
			.dump(tag: 'genome_preparation:mart_files', pretty: true)
			.set{genome_parameters}

		// -------------------------------------------------------------------------------------------------
		// get ready to emit
		// -------------------------------------------------------------------------------------------------

		parameters
			.combine(genome_parameters)
			.map{it.first().findAll{it.key != 'genome parameters'} + ['genome parameters': it.last()]}
			.dump(tag: 'genome_preparation:result', pretty: true)
			.set{result}

	emit:
		result = result
}
