
INPUT_FASTQ_TREE=/camp/stp/babs/working/barrinc/projects/guillemotf/sara.ahmeddeprado/SC_multiome_of_adult_hippocampal_neural_stem_cells/data-repository/primary_data
OUTPUT_FASTQ_TREE=/camp/svc/scratch/babs/barrinc/projects/babs/christopher.barrington/scamptest/inputs/primary_data
NRECORDS=100000

find -L ${INPUT_FASTQ_TREE}/*/fastq -name '*.fastq.gz' -printf '%h %f\n' | \
	sort | \
	sed "s|${INPUT_FASTQ_TREE}/||" | \
	awk --assign FS=' ' --assign OFS='' --assign input_fastq_tree=${INPUT_FASTQ_TREE} --assign output_fastq_tree=${OUTPUT_FASTQ_TREE} --assign nrecords=$((${NRECORDS}*4)) \
		'{print "mkdir --parents ", output_fastq_tree , "/", $1 ," ; gunzip --to-stdout ", input_fastq_tree, "/", $1, "/", $2, " | head -n ", nrecords, " | gzip --to-stdout > ", output_fastq_tree, "/", $1, "/", $2}' | \
	xargs --max-procs 16 --max-args 1 --delimiter '\n' sh -c
