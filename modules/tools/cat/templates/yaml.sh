#! bash

yq eval-all '. as \$item ireduce ({}; . * \$item )' input_* > $output_file
