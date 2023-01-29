
// -------------------------------------------------------------------------------------------------
// specify modules relevant to this workflow
// -------------------------------------------------------------------------------------------------

// include { mkref } from '../../modules/cell_ranger/mkref'
include { count } from '../../modules/cell_ranger/count'

include { add_parameter_sets ;
          check_for_matching_key_values ;
          concat_workflow_emissions ;
          concatenate_maps_list ;
          get_feature_types ;
          make_map ;
          print_as_json ;
          rename_map_keys ;
          val_to_path } from '../../modules/utilities'

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
		index_paths          = channel.of('inputs/mm10', 'inputs/mm10').map{val_to_path(it)}
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
