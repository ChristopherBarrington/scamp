#! bash

find -L input_* -type f | sort --version-sort | xargs cat > $output_file
