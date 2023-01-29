
// -------------------------------------------------------------------------------------------------
// specify modules relevant to this workflow
// -------------------------------------------------------------------------------------------------

include { read_cell_ranger_rna_atac_matrices } from '../../modules/seurat/read_cell_ranger_rna_atac_matrices'

include { merge_yaml as merge_software_versions } from '../../modules/yq/merge_yaml'

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

workflow read_matrices {

  take:
    filtered_stage_parameters
    quantified_datasets

  main:
    read_matrices(filtered_stage_parameters)
}
