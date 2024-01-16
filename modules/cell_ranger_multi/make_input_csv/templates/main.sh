#! bash

# --- write the [gene-expression] section to file ------------------------------------------------

printf '[gene-expression]\\n' \\
>> input.csv

echo reference `readlink index` $gene_expression_section_params \\
| sed 's/ /\\n/g' \\
| paste --delimiter , - - \\
>> input.csv

## add probe-set, if we are looking at a 10x-flex project
if [[ '$type' =~ -flex(-|\$) ]]; then
	echo probe-set `readlink probe_set.csv` \\
	| sed 's/ /\\n/g' \\
	| paste --delimiter , - - \\
	>> input.csv
fi

# --- write the [libraries] section to file ------------------------------------------------------

printf '\\n[libraries]\\n' \\
>> input.csv

## write a table of sample and library types
sort --key 2,2  --field-separator , <<< "$sample_types" \\
> sample_types.csv

## change the feature_types when needed
if [[ '$type' =~ -hto(-|\$) && '$type' =~ -vdj(-|\$) ]]; then
	sed --in-place 's/^Multiplexing Capture,/Antibody Capture,/' sample_types.csv
fi

## write a table of paths and sample name
find -L fastq_path_* -mindepth 1 -maxdepth 1 -regextype posix-extended -regex '.*/$fastq_files_regex' \\
| sed --regexp-extended --expression 's/$fastq_files_regex/\\1/' \\
| awk --assign OFS=',' \
     '{cmd=sprintf("basename %s", \$0); cmd | getline limsid ;
       cmd=sprintf("realpath `dirname %s`", \$0); cmd | getline path ;
       print path, limsid}' \\
| sort \\
| uniq \\
| grep --extended-regexp '($library_ids_regex)\$' \\
| sort --key 2,2 --field-separator , \\
> fastqs.csv

## combine the two files into one using the sample name as the key
join -j 2 -t , -o 1.1,1.2,2.1 fastqs.csv sample_types.csv \\
| sort --key 2,2 --key 1,1 --version-sort --field-separator , \\
| awk --assign FS=',' --assign OFS=',' 'NR==1{print "fastq_id", "fastqs", "feature_types"} {print \$2, \$1, \$3}' \\
>> input.csv

# --- write the [vdj] section to file ------------------------------------------------------------

if [[ '$type' =~ -vdj(-|\$) ]]; then
	printf '\\n[vdj]\\n' \\
	>> input.csv
	
	echo reference `readlink index_vdj` $vdj_section_params \\
	| sed 's/ /\\n/g' \\
	| paste --delimiter , - - \\
	>> input.csv
fi

# --- write the [feature] section to file --------------------------------------------------------

if [[ '$type' =~ -adt(-|\$) ]] ||
   [[ '$type' =~ -hto- && '$type' =~ -vdj(-|\$) ]]; then
	if [[ ! '$type' =~ -hto(-|\$) ]]; then
		FEATURES_REFERENCE_PATH=`readlink adt_set.csv`
	elif [[ '$type' =~ -adt- && '$type' =~ -hto- && '$type' =~ -vdj(-|\$) ]]; then
		cat adt_set.csv \\
		> features.csv
		
		awk 'NR>1{print}' hto_set.csv \\
		| sed 's/,Multiplexing Capture/,Antibody Capture/' \\
		>> features.csv

		FEATURES_REFERENCE_PATH=`realpath features.csv`
	elif [[ '$type' =~ -hto- && '$type' =~ -vdj(-|\$) ]]; then
		if [[ ! -e hto_set.csv ]]; then
		  head --lines 1 $moduleDir/assets/hto_reference.csv \\
		  > features.csv
		  
		  tail --lines +1 $moduleDir/assets/hto_reference.csv \\
		  | grep --extended-regexp '$barcodes_regex' \
		  >> features.csv
		else
		  cp `readlink hto_set.csv` features.csv
		fi

		sed --in-place 's/,Multiplexing Capture/,Antibody Capture/' features.csv

		FEATURES_REFERENCE_PATH=`realpath features.csv`
	fi

	printf '\\n[feature]\\n' \\
	>> input.csv

	echo reference \${FEATURES_REFERENCE_PATH} $feature_section_params \\
	| sed 's/ /\\n/g' \\
	| paste --delimiter , - - \\
	>> input.csv
fi

# --- write the [samples] section to file --------------------------------------------------------

if [[ '$type' =~ -flex(-|\$) ]] ||
   [[ '$type' =~ -plex(-|\$) ]] ||
   [[ '$type' =~ -hto(-|\$) && ! '$type' =~ -adt- && ! '$type' =~ -vdj(-|\$) ]]; then
	if [[ '$type' =~ -hto(-|\$) ]] ||
	   [[ '$type' =~ -plex(-|$) ]]; then
		printf '\\n[samples]\\nsample_id,cmo_ids,description\\n' \\
		>> input.csv
	else
		printf '\\n[samples]\\nsample_id,probe_barcode_ids,description\\n' \\
		>> input.csv
	fi

	sort --key 1,1  --field-separator , <<< "$sample_barcodes" \\
	>> input.csv
fi
