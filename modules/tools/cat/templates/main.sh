#! bash

find -L input_* -regextype posix-extended -regex '$regex' -type f \\
| sort --version-sort \\
| tee catted_files \\
| xargs cat > $output_file
