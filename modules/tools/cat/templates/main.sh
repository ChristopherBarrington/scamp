#! bash

find -L input_* -regextype posix-extended -regex '$regex' -type f | sort --version-sort | xargs cat > $output_file
