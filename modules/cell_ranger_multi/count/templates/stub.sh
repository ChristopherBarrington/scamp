#! bash

# run cell ranger multi
echo cellranger multi ${multi_args} \\
	--id=${output_dir} \\
	--description="Cell Ranger (multi) analysis of ${output_dir}" \\
	--csv=config.csv \\
	--jobmode=local --localcores=${task.cpus} --localmem=${task.memory.toGiga()} \\
	--disable-ui

mkdir --parents \\
${output_dir}/outs/{multi,per_sample_outs} \\
${output_dir}/outs/multi/{count,multiplexing_analysis} ${output_dir}/outs/multi/count/raw_feature_bc_matrix

touch \\
${output_dir}/outs/config.csv \\
${output_dir}/outs/multi/multiplexing_analysis/{assignment_confidence_table.csv,cells_per_tag.json,tag_calls_per_cell.csv,tag_calls_summary.csv} \\
${output_dir}/outs/multi/count/{feature_reference.csv,raw_cloupe.cloupe,raw_feature_bc_matrix,raw_feature_bc_matrix.h5,raw_molecule_info.h5,unassigned_alignments.bam,unassigned_alignments.bam.bai}

if grep --quiet '\\[samples\\]' config.csv; then
	mkdir --parents \\
	${output_dir}/outs/per_sample_outs/{${expected_datasets}}/count/{analysis,sample_filtered_feature_bc_matrix}

	touch \\
	${output_dir}/outs/per_sample_outs/{${expected_datasets}}/count/{feature_reference.csv,sample_alignments.bam,sample_alignments.bam.bai,sample_cloupe.cloupe,sample_filtered_barcodes.csv,sample_filtered_feature_bc_matrix.h5,sample_molecule_info.h5} \\
	${output_dir}/outs/per_sample_outs/{${expected_datasets}}/{metrics_summary.csv,web_summary.html}
else
	mkdir --parents \\
	${output_dir}/outs/per_sample_outs/${output_dir}/count/{analysis,sample_filtered_feature_bc_matrix}

	touch \\
	${output_dir}/outs/per_sample_outs/${output_dir}/count/{feature_reference.csv,sample_alignments.bam,sample_alignments.bam.bai,sample_cloupe.cloupe,sample_filtered_barcodes.csv,sample_filtered_feature_bc_matrix.h5,sample_molecule_info.h5} \\
	${output_dir}/outs/per_sample_outs/${output_dir}/{metrics_summary.csv,web_summary.html}

	if grep --quiet '\\[vdj\\]' config.csv; then
		mkdir --parents ${output_dir}/outs/per_sample_outs/${output_dir}/vdj_t
		touch ${output_dir}/outs/per_sample_outs/${output_dir}/vdj_t/{airr_rearrangement.tsv,cell_barcodes.json,clonotypes.csv,concat_ref.bam,concat_ref.bam.bai,concat_ref.fasta,concat_ref.fasta.fai,consensus_annotations.csv,consensus.bam,consensus.bam.bai,consensus.fasta,consensus.fasta.fai,filtered_contig_annotations.csv,filtered_contig.fasta,filtered_contig.fastq,vdj_contig_info.pb}
	fi
fi

# if the library contains only one sample, rename the per_sample_outs from id to single_sample_out
if [[ `find ${output_dir}/outs/per_sample_outs -mindepth 1 -maxdepth 1 -type d -printf '%P'` == ${output_dir} ]]; then
	mv ${output_dir}/outs/per_sample_outs/{${output_dir},${single_sample_out}}
fi

# make links to summary reports
mkdir --parents ${output_dir}/outs/per_sample_summaries \\
&& ls ${output_dir}/outs/per_sample_outs \\
| xargs --max-args 1 -I @ sh -c "mkdir ${output_dir}/outs/per_sample_summaries/@ && cp ${output_dir}/outs/per_sample_outs/@/{metrics_summary.csv,web_summary.html} ${output_dir}/outs/per_sample_summaries/@/"

# write task information to a (yaml) file
cat <<-END_TASK > task.yaml
'${task.process}':
  task:
    '${task.index}':
      params:
        id: ${output_dir}
        csv: `realpath config.csv`
      meta:
        workDir: `pwd`
  process:
    ext:
      multi: ${multi_args}
    versions:
      cell ranger: `echo "cellranger cellranger-7.1.0" | sed 's/cellranger cellranger-//'`
END_TASK
      # cell ranger: `cellranger --version | sed 's/cellranger cellranger-//'`
