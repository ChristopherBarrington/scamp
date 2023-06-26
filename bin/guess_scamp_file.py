#! /bin/env python

import argparse
import csv
import re
from ruamel.yaml import YAML
import glob, os.path, sys
import pandas as pd

if sys.version_info.major <= 3 and sys.version_info.minor < 10:
	raise Exception('Python 3.10 or a more recent version is required.')

# ------------------------------------------------------------------------------------------------
# define command line arguments
# ------------------------------------------------------------------------------------------------

parser = argparse.ArgumentParser(
	description='Creates a template scamp parameters file that could be used to run the pipeline. The parameters are guessed so should be checked first!',
	epilog=f'Example: {sys.argv[0]} --lims-id SC22034 --genome mm10',
	formatter_class=argparse.RawDescriptionHelpFormatter)

group = parser.add_mutually_exclusive_group(required=True)

group.add_argument(
	"--lims-id", type=str, required=False, dest='lims_id',
	help="A LIMS ID that could be found in the `data` directory.")

group.add_argument(
	"--data-path", type=str, required=False, dest='data_path',
	help="Path to the data directory for a project, it should contain `primary_data` and `{lims-id}_design.csv`.")

parser.add_argument(
	'--genomes', type=str, nargs='+', required=True, dest='genomes',
	help='Genomes included in any dataset in the project.',
	choices=['mm10', 'GRCh38'])

parser.add_argument(
	'--data-root', type=str, required=False, dest='data_root',
	help='Root path of the data directories.',
	default='/nemo/stp/babs/inputs/sequencing/data')

parser.add_argument(
	'--output-file', type=str, required=False, dest='output_file',
	help='Name of the output file that will be written (or overwritten).',
	default='scamp-file.yaml')

parser.add_argument(
	'--project-type', type=str, required=False, dest='project_type',
	help='Protocol used to generate these datasets.',
	choices=['10X-3prime', '10X-Multiomics', '10X-FeatureBarcoding'])

parser.add_argument(
	'--design-file', type=str, required=False, dest='design_file',
	help='Path to sample sheet CSV file.')

args = parser.parse_args()

# ------------------------------------------------------------------------------------------------
# lims_id or data_path must be provided!
# ------------------------------------------------------------------------------------------------

def validate_arguments():
	exit_early = False

	if args.lims_id is None and args.data_path is None:
		print('neither `lims_id` or `data_path` were provided!')
		exit_early = True

	if args.lims_id is not None and re.search('SC\d{5}', args.lims_id) is False:
		print('`lims_id` looks wrongs - expecting "SC\d{5} in {}"!'.format(arg.lims_id))
		exit_early = True

	if args.data_path is not None and os.path.exists(args.data_path) is False:
		print('`data_path` was provided but does not exist!')
		exit_early = True

	if os.path.exists(args.data_root) is False:
		print('`data_root` but does not exist!')
		exit_early = True

	if exit_early == True:
		sys.exit()

	if args.data_path is None: find_data_path_from_lims_id()
	if args.lims_id is None: get_lims_id_from_data_path()
	if args.design_file is None: get_design_file_path()
	if args.project_type is None: get_project_type_from_sample_sheet()

	args.fastq_paths_glob = os.path.join(args.data_path, 'primary_data', '*', 'fastq')
	args.genome = args.genomes[0]

# if only given a lims id, find that directory
def find_data_path_from_lims_id():
	if args.lims_id is None:
		print('cannot find a lims directory without `lims_id`!')
		sys.exit()
	else:
		paths = glob.glob(os.path.join(args.data_root, '*', '*', '*'))
		path = list(filter(lambda x: x.find(args.lims_id) != -1, paths))
		if len(path) == 0:
			print('no path found to {} via {}'.format(args.lims_id, args.data_root))
			sys.exit()
		if len(path) > 1:
			print('multiple paths found to {} via {}'.format(args.lims_id, args.data_root))
			sys.exit()
		else:
			args.data_path = path.pop(0)

# if lims id is not provided, get it from the data path
def get_lims_id_from_data_path():
	args.lims_id = os.path.basename(args.data_path)

# get design file path
def get_design_file_path():
	args.design_file = os.path.join(args.data_path, "{}_design.csv".format(args.lims_id))

# parse sample sheet to get project type
def get_project_type_from_sample_sheet():
	sample_sheet = read_design_file()
	project_types = list(sample_sheet['type'].unique())
	if len(project_types) != 1:
		print('multiple project types found in the sample sheet!')
		sys.exit()
	else:
		args.project_type = project_types[0]

# ------------------------------------------------------------------------------------------------
# get the genome information for genomes included in the project
# ------------------------------------------------------------------------------------------------

def get_genome_parameters():
	defaults = {
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

	genomes = {k:defaults[k] for k in args.genomes if k in defaults}
	return(genomes)

# ------------------------------------------------------------------------------------------------
# get the fastq directories for this lims id using data_path
# ------------------------------------------------------------------------------------------------

def get_fastq_paths_from_data_path():
	paths = glob.glob(args.fastq_paths_glob)
	paths.sort(key=natural_keys)
	return(paths)

# ------------------------------------------------------------------------------------------------
# get the lab and scientist from data_path
# ------------------------------------------------------------------------------------------------

def get_names_from_data_path():
	who = args.data_path.split(os.path.sep)
	lab = who[-3]
	scientist = who[-2]
	return(lab, scientist)

# ------------------------------------------------------------------------------------------------
# read and filter a sample sheet, checking that required columns exist
# ------------------------------------------------------------------------------------------------

def read_design_file():
	df = pd.read_csv(args.design_file)
	important_columns = ['sample_lims', 'sample_name', 'type', 'fastq_1']
	for important_column in important_columns:
		if important_column not in df.columns:
			print('`{}` undefined in sample sheet {}!'.format(important_column, args.design_file))
			sys.exit()
		df = df[df[important_column].isnull() == False]
	return(df)

# ------------------------------------------------------------------------------------------------
# parse the sample sheet in `data` to guess library types
# ------------------------------------------------------------------------------------------------

def get_feature_types_to_search_terms():
	# dictionary of search terms in `sample_name` and their feature type
	return({
		'Gene Expression': ['_GEX$', '_mxGEX$'],
		'Chromatin Accessibility': ['_ATAC$', '_mxATAC$'],
		'CMO': ['_CMO$']})

def get_library_types():
	library_types = {}
	sample_lims_ids = {}
	sample_sheet = read_design_file()
	feature_types_to_search_terms = get_feature_types_to_search_terms()

	# add the library type column to check that all rows get assigned
	sample_sheet['library_type'] = 'unassigned'

	# add in feature type columns based on the regex and sample name
	for feature_type in feature_types_to_search_terms.keys():
		sample_name_regexes = feature_types_to_search_terms[feature_type]
		sample_name_regex = '|'.join(sample_name_regexes)
		sample_sheet[feature_type] = sample_sheet['sample_name'].str.contains(sample_name_regex)
		sample_sheet.loc[sample_sheet[feature_type] == True, 'library_type'] = feature_type

	# remove any feature type regex from the sample name
	all_sample_name_regexes = [item for sublist in feature_types_to_search_terms.values() for item in sublist]
	all_sample_name_regexes = '|'.join(all_sample_name_regexes)
	all_sample_name_regexes = '({})'.format(all_sample_name_regexes)	
	sample_sheet['sample_name_group'] = sample_sheet['sample_name'].map(lambda x: re.sub(all_sample_name_regexes, '', x))

	# check that every row has a feature type
	if (sample_sheet['library_type'].eq('unassigned')).any():
		sample_sheet[sample_sheet['library_type'] == 'unassigned']	
		print('some rows could not be assigned a feature type! check sample name regexes!')

	# check that every row had exactly one feature type regex match
	sample_sheet['total_feature_type_matches'] = sample_sheet[feature_types_to_search_terms.keys()].sum(axis=1)
	if sample_sheet['total_feature_type_matches'].gt(1).any():
		sample_sheet[sample_sheet['total_feature_type_matches'] > 1]	
		print('some rows contained more than one feature type! check sample name regexes!')

	# get a dictionary of lims id in library type groups
	library_types = sample_sheet.groupby(['library_type'])['sample_lims'].apply(set).apply(list).to_dict()	
	library_types = {k:sorted(library_types[k], key=natural_keys) for k in library_types} # sort the lims ids

	# get a dictionary of lims id in sample name groups
	sample_lims_ids = sample_sheet.groupby(['sample_name_group'])['sample_lims'].apply(set).apply(list).to_dict()	
	sample_lims_ids = {k:sorted(sample_lims_ids[k], key=natural_keys) for k in sample_lims_ids} # sort the lims ids

	# return library_types and sample_lims_ids
	return(library_types, sample_lims_ids)

# ------------------------------------------------------------------------------------------------
# values taken from `project_type`
# ------------------------------------------------------------------------------------------------

def get_dataset_index():
	match args.project_type:
		case '10X-3prime':
			return({
				'mm10': 'inputs/refdata-gex-mm10-2020-A',
				'GRCh38': 'inputs/refdata-gex-GRCh38-2020-A'}.get(args.genome))

		case '10X-Multiomics':
			return({
				'mm10': 'inputs/refdata-cellranger-arc-mm10-2020-A-2.0.0',
				'GRCh38': 'inputs/refdata-cellranger-arc-GRCh38-2020-A-2.0.0'}.get(args.genome))

		case '10X-FeatureBarcoding':
			return({
				'mm10': 'inputs/refdata-cellranger-arc-mm10-2020-A-2.0.0',
				'GRCh38': 'inputs/refdata-cellranger-arc-GRCh38-2020-A-2.0.0'}.get(args.genome))

		case _:
			print("UNKNOWN PROJECT TYPE: {}".format(args.project_type))
			sys.exit()

def get_feature_types():
	match args.project_type:
		case '10X-3prime': return(['Gene Expression'])
		case '10X-Multiomics': return(['Gene Expression', 'Chromatin Accessibility'])
		case '10X-FeatureBarcoding':return(['Gene Expression', 'CMO'])
		case _:
			print("UNKNOWN PROJECT TYPE: {}".format(args.project_type))
			sys.exit()

def get_stages():
	match args.project_type:
		case '10X-3prime': return(['quantification/cell_ranger', 'seurat/prepare/cell_ranger'])
		case '10X-Multiomics': return(['quantification/cell_ranger_arc', 'seurat/prepare/cell_ranger_arc'])
		case '10X-FeatureBarcoding': return(['quantification/cell_ranger_multi', 'seurat/prepare/cell_ranger'])
		case _:
			print("UNKNOWN PROJECT TYPE: {}".format(args.project_type))
			sys.exit()


# ------------------------------------------------------------------------------------------------
# get datasets parameter from sample to lims id dictionary
# ------------------------------------------------------------------------------------------------

def get_datasets(sample_lims_ids):
	return({k:{'limsid': sample_lims_ids[k]} for k in sample_lims_ids})

# ------------------------------------------------------------------------------------------------
# write the guessed parameters file
# ------------------------------------------------------------------------------------------------

def write_formatted_scamp_file(params):
	print('writing template scamp parameters to {}. CHECK THE CONTENTS!'.format(args.output_file))
	with open(args.output_file, 'w') as outfile:
		yaml = YAML()
		yaml.width = 4096
		yaml.indent(mapping=4, offset=4, sequence=4)
		yaml.dump(params, stream=outfile)

# ------------------------------------------------------------------------------------------------
# extra functions needed to get other stuff working
# ------------------------------------------------------------------------------------------------

# so that we can naturally sort the lims ids
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
# call these functions to get the parameters into a structure that can be written as yaml
# ------------------------------------------------------------------------------------------------

def main():
	# check and fill in command line arguments
	validate_arguments()

	# get parameters from args-dependent information
	stages = get_stages()
	genomes = get_genome_parameters()
	fastq_paths = get_fastq_paths_from_data_path()
	dataset_index = get_dataset_index()
	feature_types = get_feature_types()
	lab,scientist = get_names_from_data_path()
	library_types, sample_lims_ids = get_library_types()

	# get parameters dependent on the above variables
	datasets = get_datasets(sample_lims_ids)

	# put the parameters together
	params = {
		'_project': {
			'lab': lab,
			'scientist': scientist,
			'lims id': args.lims_id,
			'babs id': 'unknown',
			'type': args.project_type,
			'genomes': genomes},
		'_defaults': {
			'genome': args.genome,
			'fastq paths': fastq_paths,
			'feature types': library_types,
			'index path': dataset_index,
			'stages': stages},
		'analysis': {
			'_defaults': {
				'feature identifiers': 'name'}} | datasets}

	# write the above structure to a yaml file
	write_formatted_scamp_file(params)

main()
