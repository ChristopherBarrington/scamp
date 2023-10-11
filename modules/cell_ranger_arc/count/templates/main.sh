#! bash

# filter the complete libraries file for the samples in this dataset
awk --assign FS=',' 'NR==1{print} ; \$2~/^($samples_regex)\$/{print}' all_libraries.csv > libraries.csv

# run cell ranger arc count
cellranger-arc count $count_args \\
	--id=$id \\
	--description="$description" \\
	--libraries=libraries.csv \\
	--reference=index_path \\
	--jobmode=local --localcores=${task.cpus} --localmem=${task.memory.toGiga()} \\
	--disable-ui

# make links to summary reports
ln --symbolic $id/outs/web_summary.html joint_summary.html

find $id/SC_ATAC_GEX_COUNTER_CS/SC_ATAC_GEX_COUNTER/_SC_ATAC_REPORTER/CREATE_WEBSUMMARY -name 'web_summary.html' |
	head --lines 1 |
	xargs --max-args 1 -I @ ln --symbolic @ atac_summary.html

find $id/SC_ATAC_GEX_COUNTER_CS/SC_ATAC_GEX_COUNTER/GEX_SUMMARIZE_REPORTS -name 'web_summary.html' |
	head --lines 1 |
	xargs --max-args 1 -I @ ln --symbolic @ rna_summary.html

# write task information to a (yaml) file
cat <<-END_TASK > task.yaml
'${task.process}':
  task:
    '${task.index}':
      params:
        id: $id
        samples: $samples
        description: $description
        index_path: `realpath index_path`
        complete_libraries: `realpath all_libraries.csv`
      meta:
        workDir: `pwd`
  process:
    ext:
      count: ${count_args}
    versions:
      cell ranger arc: `cellranger-arc --version | sed 's/cellranger-arc cellranger-arc-//'`
END_TASK
