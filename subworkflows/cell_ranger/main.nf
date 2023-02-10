
// -------------------------------------------------------------------------------------------------
// specify modules relevant to this workflow
// -------------------------------------------------------------------------------------------------

// include { mkref } from '../../modules/cell_ranger/mkref'
include { count } from '../../modules/cell_ranger/count'

include { make_map }      from '../../modules/utilities/make_map'
include { print_as_json } from '../../modules/utilities/print_as_json'

// -------------------------------------------------------------------------------------------------
// define the workflow
// -------------------------------------------------------------------------------------------------

workflow cell_ranger {

	take:
		filtered_stage_parameters

	main:
		// -------------------------------------------------------------------------------------------------
		// run cell ranger
		// -------------------------------------------------------------------------------------------------

		// make channels of parameters for samples that need to be quantified
		unique_identifiers   = channel.of('UID1', 'UID2')
		dataset_names        = channel.of('foo 123', 'bar 456')
		dataset_directories  = channel.of('foo_123', 'bar_456')
		index_paths          = channel.fromPath(['inputs/mm10', 'inputs/mm10'])
		additional_arguments = channel.value('')

		count(unique_identifiers, dataset_names, dataset_directories, index_paths, additional_arguments)

		// make a channel of dataset (names) and paths that contain quantified data
		count.out.uid
			.merge(count.out.index_path)
			.merge(count.out.quantification_path)
			.map{ x -> make_map(x+['DSN','cell ranger'], ['unique id', 'index path','quantification path', 'dataset name', 'stage name']) }
			.dump(tag: 'cell_ranger:quantified_datasets', pretty: true)
			.set{quantified_datasets}

	emit:
		subworkflows         = quantified_datasets.count().flatMap{['cell ranger'].multiply(it)}
		unique_ids           = quantified_datasets.flatMap{it.get('unique id')}
		stage_names          = quantified_datasets.flatMap{it.get('stage name')}
		dataset_names        = quantified_datasets.flatMap{it.get('dataset name')}
		index_paths          = quantified_datasets.flatMap{it.get('index path')}
		quantification_paths = quantified_datasets.flatMap{it.get('quantification path')}
		report               = channel.of('report.document')
}
