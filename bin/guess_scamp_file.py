#! python

import argparse
import csv
import re
from ruamel.yaml import YAML
import glob, os.path, sys

# ------------------------------------------------------------------------------------------------
# define command line arguments
# ------------------------------------------------------------------------------------------------

parser = argparse.ArgumentParser(
    description='Creates a template scamp parameters file that could be used to run the pipeline. The parameters are guessed so should be checked first!',
    epilog=f'Example: {sys.argv[0]} --lims-id SC22034 --genome mm10',
    formatter_class=argparse.RawDescriptionHelpFormatter)

group = parser.add_mutually_exclusive_group(required=True)

group.add_argument(
    "--lims-id", type=str, required=False, 
    help="A LIMS ID that could be found in the `data` directory.")

group.add_argument(
    "--data-path", type=str, required=False, 
    help="Path to the data directory for a project, it should contain `primary_data` and `{lims-id}_design.csv`.")

parser.add_argument(
	'--genome', type=str, required=True,
	help='Genome in which the data should be analysed.',
	choices=['mm10', 'GRCh38'])

parser.add_argument(
	'--data-root', type=str, required=False,
	help='Root path of the data directories.',
	default='/nemo/stp/babs/inputs/sequencing/data')

parser.add_argument(
	'--output-file', type=str, required=False,
	help='Name of the output file that will be written (or overwritten).',
	default='scamp-file.yaml')

args = parser.parse_args()

genome = args.genome
lims_id = args.lims_id
data_path = args.data_path
data_root = args.data_root
output_file = args.output_file

print("genome: {}".format(genome))
print("lims_id: {}".format(lims_id))
print("data_path: {}".format(data_path))
print("data_root: {}".format(data_root))
print("output_file: {}".format(output_file))

# ------------------------------------------------------------------------------------------------
# lims_id or data_path must be provided!
# ------------------------------------------------------------------------------------------------

if lims_id is None and data_path is None:
	print('neither `lims_id` or `data_path` were provided!')
	sys.exit()

# ------------------------------------------------------------------------------------------------
# get the genome information for genomes included in the project
# ------------------------------------------------------------------------------------------------

genomes_defaults = {
	'mm10': {
		'organism': 'mus musculus',
		'assembly': 'mm10',
		'ensembl release': 98,
		'non-nuclear contigs': ['chrM'],
		'mitochondrial features': 'inputs/mm10_mitochondrial_genes.yaml'},
	'GRCh38': {
		'organism': 'homo sapiens',
		'assembly': 'GRCh38',
		'ensembl release': 98,
		'non-nuclear contigs': ['chrM'],
		'mitochondrial features': 'inputs/GRCh38_mitochondrial_genes.yaml'}}

project_genomes = {k:genomes_defaults[k] for k in [genome] if k in genomes_defaults}

# ------------------------------------------------------------------------------------------------
# extra functions needed to get other stuff working
# ------------------------------------------------------------------------------------------------

# stuff to sort lims ids
def atoi(text):
	return int(text) if text.isdigit() else text

def natural_keys(text):
	'''
	alist.sort(key=natural_keys) sorts in human order
	http://nedbatchelder.com/blog/200712/human_sorting.html
	(See Toothy's implementation in the comments)
	'''
	return [ atoi(c) for c in re.split(r'(\d+)', text) ]

# ------------------------------------------------------------------------------------------------
# if only given a lims id, find that directory
# ------------------------------------------------------------------------------------------------

if data_path is None:
	if lims_id is None:
		print('cannot find a lims directory without `lims_id`!')
		sys.exit()
	else:
		data_paths = glob.glob(os.path.join(data_root, '*', '*', '*'))
		data_path = list(filter(lambda x: x.find(lims_id) != -1, data_paths)).pop(0)

# ------------------------------------------------------------------------------------------------
# get the fastq directories for this lims id
# ------------------------------------------------------------------------------------------------

fastq_paths = glob.glob(os.path.join(data_path, 'primary_data', '*', 'fastq'))
fastq_paths.sort(key=natural_keys)

# ------------------------------------------------------------------------------------------------
# get the lab, scientist info
# ------------------------------------------------------------------------------------------------

who = data_path.split(os.path.sep)
lab = who[-3]
scientist = who[-2]
lims_id = who[-1]

# ------------------------------------------------------------------------------------------------
# parse the sample sheet in `data` to guess library types
# ------------------------------------------------------------------------------------------------

design_file = os.path.join(data_path, "{}_design.csv".format(lims_id))

# dictionary of search terms in `sample_name` and their feature type
names_to_feature_types = {
	'_GEX$': 'Gene Expression',
	'_mxGEX$': 'Gene Expression',
	'_ATAC$': 'Chromatin Accessibility',
	'_mxATAC$': 'Chromatin Accessibility',
	'_CMO$': 'CMO',
	'$': 'Gene Expression'}

# search for these regexes and populate the following variables
library_types = {}
project_types = []
sample_lims_ids = {}

with open(design_file, 'r') as csvfile:
	design_file_reader = csv.DictReader(csvfile)
	for design_file_row in design_file_reader:
		row_limsid = design_file_row.get('sample_lims')
		if row_limsid is None or row_limsid == '':
			print(design_file_row)
			print('`sample_lims` undefined in sample sheet!')
			sys.exit()
		#
		row_sample_name = design_file_row.get('sample_name')
		if row_sample_name is None or row_sample_name == '':
			print(design_file_row)
			print('`sample_name` undefined in sample sheet!')
			sys.exit()
		#
		row_project_type = design_file_row.get('type')
		if row_project_type is None or row_project_type == '':
			print(design_file_row)
			print('`type` undefined in sample sheet!')
			sys.exit()
		#
		row_fastq1 = design_file_row.get('fastq_1')
		if row_fastq1 is None:
			print(design_file_row)
			print('`type` undefined in sample sheet!')
			sys.exit()
		elif row_fastq1 == '':
			pass
		#
		project_types.append(row_project_type)
		#
		for feature_type_regex in list(names_to_feature_types.keys()):
			if(bool(re.search(feature_type_regex, row_sample_name))):
				sample_name = re.sub(feature_type_regex, '', row_sample_name)
				sample_lims_ids[sample_name] = sample_lims_ids.get(sample_name, []) + [row_limsid]
				feature_type = names_to_feature_types[feature_type_regex]
				library_types[feature_type] = library_types.get(feature_type, []) + [row_limsid]
				break

library_types = {k:list(set(library_types[k])) for k in library_types} # get unique lims ids
library_types = {k:sorted(library_types[k], key=natural_keys) for k in library_types} # sort the lims ids

sample_lims_ids = {k:list(set(sample_lims_ids[k])) for k in sample_lims_ids} # get unique lims ids
sample_lims_ids = {k:sorted(sample_lims_ids[k], key=natural_keys) for k in sample_lims_ids} # sort the lims ids

project_types = list(set(project_types))
if len(project_types) != 1:
	print('multiple project types found in the sample sheet!')
	sys.exit()
else:
	project_type = project_types[0]

# ------------------------------------------------------------------------------------------------
# values taken from `project_type`
# ------------------------------------------------------------------------------------------------

match project_type:
	case '10X-3prime':
		dataset_index = {
			'mm10': 'inputs/refdata-gex-mm10-2020-A',
			'GRCh38': 'inputs/refdata-gex-GRCh38-2020-A'}.get(genome)
		feature_types = ['Gene Expression']
		dataset_stages = ['quantification/cell_ranger', 'seurat/prepare/cell_ranger']
	#
	case '10X-Multiomics':
		dataset_index = {
			'mm10': 'inputs/refdata-cellranger-arc-mm10-2020-A-2.0.0',
			'GRCh38': 'inputs/refdata-cellranger-arc-GRCh38-2020-A-2.0.0'}.get(genome)
		feature_types = ['Gene Expression', 'Chromatin Accessibility']
		dataset_stages = ['quantification/cell_ranger_arc', 'seurat/prepare/cell_ranger_arc']
	#
	case '10X-FeatureBarcoding':
		dataset_index = {
			'mm10': 'inputs/refdata-cellranger-arc-mm10-2020-A-2.0.0',
			'GRCh38': 'inputs/refdata-cellranger-arc-GRCh38-2020-A-2.0.0'}.get(genome)
		feature_types = ['Gene Expression', 'CMO']
		dataset_stages = ['quantification/cell_ranger_multi', 'seurat/prepare/cell_ranger']
	#
	case _:
		print("UNKNOWN PROJECT TYPE: {}".format(project_type))
		sys.exit()

# ------------------------------------------------------------------------------------------------
# get datasets parameter
# ------------------------------------------------------------------------------------------------

datasets = {k:{'limsid': sample_lims_ids[k]} for k in sample_lims_ids} # get unique lims ids

# ------------------------------------------------------------------------------------------------
# put the parameters together
# ------------------------------------------------------------------------------------------------

params = {
	'_project': {
		'lab': lab,
		'scientist': scientist,
		'lims id': lims_id,
		'babs id': 'unknown',
		'genomes': project_genomes},
	'_defaults': {
		'genome': genome,
		'fastq paths': fastq_paths,
		'feature types': library_types,
		'index path': dataset_index,
		'stages': dataset_stages},
	'analysis': {
		'_defaults': {
			'feature identifiers': 'name'}} | datasets}

# ------------------------------------------------------------------------------------------------
# write the guessed parameters file
# ------------------------------------------------------------------------------------------------

with open(output_file, 'w') as outfile:
	yaml = YAML()
	yaml.indent(mapping=4, offset=4, sequence=4)
	yaml.width = 4096
	yaml.dump(params, stream=outfile)
