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
			.set{fasta_file}

		fasta_file.to_make.dump(tag: 'genome_preparation:fasta_file.to_make', pretty: true)
		fasta_file.to_skip.dump(tag: 'genome_preparation:fasta_file.to_skip', pretty: true)

		// make channels of parameters
		fasta_path  = fasta_file.to_make.map{it.get('fasta path')}
		output_file = fasta_file.to_make.map{it.get('id') + '.fa'}

		// run the process
		cat_fastas([:], fasta_path, output_file)

		// make a channel of newly created parameters
		merge_process_emissions(cat_fastas, ['opt', 'path'])
			.map{rename_map_keys(it, 'path', 'fasta file')}
			.map{merge_metadata_and_process_output(it)}
			.concat(fasta_file.to_skip)
			.dump(tag: 'genome_preparation:fasta_file', pretty: true)
			.set{fasta_file}

		// -------------------------------------------------------------------------------------------------
		// make fasta index for genome
		// -------------------------------------------------------------------------------------------------

		// branch parameters into multiple channels using key(s)
		fasta_file
			.branch{
				def has_fasta_file = it.containsKey('fasta file')
				def has_fasta_index_file = it.containsKey('fasta index file')
				to_make: has_fasta_file & !has_fasta_index_file
				to_skip: !has_fasta_file | has_fasta_index_file}
			.set{fasta_index_file}

		fasta_index_file.to_make.dump(tag: 'genome_preparation:fasta_index_file.to_make', pretty: true)
		fasta_index_file.to_skip.dump(tag: 'genome_preparation:fasta_index_file.to_skip', pretty: true)

		// make channels of parameters
		input_file = fasta_index_file.to_make.map{it.get('fasta file')}

		// run the process
		faidx([:], input_file)

		// make a channel of newly created parameters
		merge_process_emissions(faidx, ['opt', 'path'])
			.map{rename_map_keys(it, 'path', 'fasta index file')}
			.map{merge_metadata_and_process_output(it)}
			.concat(fasta_index_file.to_skip)
			.merge(fasta_file)
			.map{concatenate_maps_list(it)}
			.dump(tag: 'genome_preparation:fasta_index_file', pretty: true)
			.set{fasta_index_file}

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
			.set{gtf_file}

		gtf_file.to_make.dump(tag: 'genome_preparation:gtf_file.to_make', pretty: true)
		gtf_file.to_skip.dump(tag: 'genome_preparation:gtf_file.to_skip', pretty: true)

		// make channels of parameters
		gtf_path    = gtf_file.to_make.map{it.get('gtf path')}
		output_file = gtf_file.to_make.map{it.get('id') + '.gtf'}

		// run the process
		cat_gtfs([:], gtf_path, '.*.gtf', output_file)

		// make a channel of newly created parameters
		merge_process_emissions(cat_gtfs, ['opt', 'path'])
			.map{rename_map_keys(it, 'path', 'gtf file')}
			.map{merge_metadata_and_process_output(it)}
			.concat(gtf_file.to_skip)
			.dump(tag: 'genome_preparation:gtf_file', pretty: true)
			.set{gtf_file}

		// -------------------------------------------------------------------------------------------------
		// make GRanges objects for gene annotations of the genomes
		// -------------------------------------------------------------------------------------------------

		// branch parameters into multiple channels using key(s)
		genome_parameters
			.combine(fasta_index_file)
			.combine(gtf_file)
			.map{concatenate_maps_list(it)}
			.branch{
				def has_fasta_index_file = it.containsKey('fasta index file')
				def has_gtf_file = it.containsKey('gtf file')
				to_make: has_fasta_index_file & has_gtf_file
				to_skip: !has_fasta_index_file | !has_gtf_file}
		 	.set{granges_file}

		granges_file.to_make.dump(tag: 'genome_preparation:granges_file.to_make', pretty: true)
		granges_file.to_skip.dump(tag: 'genome_preparation:granges_file.to_skip', pretty: true)

		// make channels of parameters
		genome = granges_file.to_make.map{it.get('id')}
		gtf    = granges_file.to_make.map{it.get('gtf file')}
		fai    = granges_file.to_make.map{it.get('fasta index file')}

		// run the process
		convert_gtf_to_granges([:], genome, gtf, fai)

		// make a channel of newly created parameters
		merge_process_emissions(convert_gtf_to_granges, ['opt', 'granges'])
			.map{merge_metadata_and_process_output(it)}
			.concat(granges_file.to_skip)
			.dump(tag: 'genome_preparation:granges_file', pretty: true)
			.set{granges_file}

		// -------------------------------------------------------------------------------------------------
		// make a biomaRt object for the genome
		// -------------------------------------------------------------------------------------------------

		// // branch parameters into multiple channels using key(s)
		genome_parameters
			.branch{
				def has_ensembl_release = it.containsKey('ensembl release')
				to_make: has_ensembl_release
				to_skip: !has_ensembl_release}
			.set{mart_file}

		mart_file.to_make.dump(tag: 'genome_preparation:mart_file.to_make', pretty: true)
		mart_file.to_skip.dump(tag: 'genome_preparation:mart_file.to_skip', pretty: true)

		// make channels of parameters
		organism        = mart_file.to_make.map{it.get('organism')}
		ensembl_release = mart_file.to_make.map{it.get('ensembl release')}

		// run the process
		get_mart([:], organism, ensembl_release)

		// make a channel of newly created parameters
		merge_process_emissions(get_mart, ['opt', 'mart'])
			.map{rename_map_keys(it, 'mart', 'biomart connection')}
			.map{merge_metadata_and_process_output(it)}
			.concat(mart_file.to_skip)
			.dump(tag: 'genome_preparation:mart_file', pretty: true)
			.set{mart_file}

		// -------------------------------------------------------------------------------------------------
		// get ready to emit
		// -------------------------------------------------------------------------------------------------

		genome_parameters
			.combine(fasta_index_file)
			.combine(gtf_file)
			.combine(granges_file)
			.combine(mart_file)
			.map{concatenate_maps_list(it)}
			.dump(tag: 'genome_preparation:complete_genome_parameters', pretty: true)
			.set{complete_genome_parameters}

		parameters
			.combine(complete_genome_parameters)
			.map{it.first().findAll{it.key != 'genome parameters'} + ['genome parameters': it.last()]}
			.dump(tag: 'genome_preparation:result', pretty: true)
			.set{result}

	emit:
		result = result
}
