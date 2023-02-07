
// -------------------------------------------------------------------------------------------------
// specify modules relevant to this workflow
// -------------------------------------------------------------------------------------------------

include { read_cell_ranger_rna_atac_matrices } from '../../modules/seurat/read_cell_ranger_rna_atac_matrices'

include { merge_yaml as merge_software_versions } from '../../modules/yq/merge_yaml'

include { print_as_json } from '../../modules/utilities/print_as_json'

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
