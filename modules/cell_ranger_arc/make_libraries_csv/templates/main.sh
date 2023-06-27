#! bash

# write a table of sample and library types
sort --key 2,2  --field-separator , <<< "$sample_types" > sample_types.csv

# write a table of paths and sample name
find -L fastq_path_* -mindepth 1 -maxdepth 1 -regextype posix-extended -regex ".*/$fastq_files_regex" |
sed --regexp-extended --expression 's/$fastq_files_regex/\\1/' |
uniq |
awk --assign OFS=',' \
     '{cmd=sprintf("basename %s", \$0); cmd | getline limsid ;
       cmd=sprintf("realpath `dirname %s`", \$0); cmd | getline path ;
       print path, limsid}' |
sort --key 2,2 --field-separator , > fastqs.csv

# combine the two files into one using the sample name as the key
join -j 2 -t , -o 1.1,1.2,2.1 fastqs.csv sample_types.csv |
sort --key 2,2 --key 1,1 --version-sort --field-separator , |
awk --assign OFS=',' 'NR==1{print "fastqs", "sample", "library_type"} {print}' > libraries.csv
