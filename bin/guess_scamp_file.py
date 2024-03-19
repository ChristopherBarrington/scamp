#! /bin/env python

import argparse
import csv
import glob, os.path, sys
import pandas
import re, regex_spm

from ruamel.yaml import YAML

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
	'--lims-id', type=str, required=False, dest='lims_id',
	help='A LIMS ID that could be found in the `data` directory.')

group.add_argument(
	'--data-path', type=str, required=False, dest='data_path',
	help='Path to the data directory for a project, it should contain `primary_data` and `{lims-id}_design.csv`.')

parser.add_argument(
	'--lab', type=str, required=False, dest='lab',
	help='<lastname><initial> format for the lab.')

parser.add_argument(
	'--scientist', type=str, required=False, dest='scientist',
	help='<firstname>.<lastname> format for the scientist')

parser.add_argument(
	'--genome', type=str, required=True, dest='genome',
	help='Genome used in the project.',
	choices=['mm10', 'GRCh38', 'BDGP6.22', 'GRCg6a'])

parser.add_argument(
	'--data-root', type=str, required=False, dest='data_root',
	help='Root path of the data directories.',
	default='/nemo/stp/babs/inputs/sequencing/data')

parser.add_argument(
	'--output-file', type=str, required=False, dest='output_file',
	help='Name of the output file that will be written (or overwritten).',
	default='scamp_file.yaml')

parser.add_argument(
	'--project-type', type=str, required=False, dest='project_type',
	help='Protocol used to generate these datasets.')
	# choices=['10X-3prime', '10X-Multiomics', '10X-FeatureBarcoding'])

parser.add_argument(
	'--project-assays', type=str, required=False, dest='project_assays', nargs='+',
	help='A list of the assays used in the project. These are a curated set of keywords.',
	choices=['10x', '3prime', '5prime', 'adt', 'bcr', 'flex', 'hto', 'plex', 'tcr'])

parser.add_argument(
	'--design-file', type=str, required=False, dest='design_file',
	help='Path to sample sheet CSV file.')

parser.add_argument(
	'--barcodes-file', type=str, required=False, dest='barcodes_file',
	help='Path to barcodes CSV file with "barcode" and "sample_name" columns.')

parser.add_argument(
	'--antibodies-file', type=str, required=False, dest='antibodies_file',
	help='Path to antibodies CSV file with antibody and tag information.')

parser.add_argument(
	'--hto-file', type=str, required=False, dest='hto_file',
	help='Path to CSV for HTO antibody tags. Can be omitted in which case the default TotalSeq set is used from the module assets.')

parser.add_argument(
	'--probes-file', type=set, required=False, dest='probes_file',
	help='Path to 10x probes file for Flex analyses.')

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

	if exit_early == True:
		sys.exit()

	if args.data_path is None: get_data_path()
	if args.lab is None: get_lab_from_data_path()
	if args.lims_id is None: get_lims_id_from_data_path()
	if args.scientist is None: get_scientist_from_data_path()
	if args.design_file is None: get_design_file_path()
	if args.project_type is None: get_project_type_from_assays()
	if args.project_assays is None: get_project_assays_from_type()

	if not args.project_type.startswith('10x-'):
		args.project_type = '10x-' + args.project_type

	if '10x' not in args.project_assays:
		args.project_assays.insert(0, '10x')

	if any([x in ['hto', 'flex', 'plex'] for x in args.project_assays]) and args.barcodes_file is None:
		print('a multiplexing design was specified but no --barcodes-file provided')
		sys.exit()

	args.fastq_paths_glob = os.path.join(args.data_path, 'primary_data', '*', 'fastq')

# if only given a lims id, find that directory
def get_data_path():
	if args.lims_id is None:
		print('cannot find a lims directory without `lims_id`!')
		sys.exit()
	
	elif args.lab is not None and args.scientist is not None:
		args.data_path = os.path.join(args.data_root, args.lab, args.scientist, args.lims_id)

	else:
		path = find_data_path()
		if path is None:
			print('no path found to {} via {}'.format(args.lims_id, args.data_root))
			sys.exit()
		else:
			args.data_path = path

def find_data_path():
	search_path = args.data_root

	if args.lab is None:
		search_path = os.path.join(search_path, '*')
	else:
		search_path = os.path.join(search_path, args.lab)

	if args.scientist is None:
		search_path = os.path.join(search_path, '*')
	else:
		search_path = os.path.join(search_path, args.scientist)

	search_paths = glob.glob(os.path.join(search_path, args.lims_id))

	for path in search_paths:
		if os.path.exists(path):
			return(path)

# if lab, scientist or lims id are not provided, get them from the data path
def get_lims_id_from_data_path():
	args.lims_id = args.data_path.split(os.path.sep)[-1]

def get_scientist_from_data_path():
	args.scientist = args.data_path.split(os.path.sep)[-2]

def get_lab_from_data_path():
	args.lab = args.data_path.split(os.path.sep)[-3]

# get design file path
def get_design_file_path():
	args.design_file = os.path.join(args.data_path, "{}_design.csv".format(args.lims_id))

def get_project_type_from_assays():
	if args.project_assays is None:
		print('cannot get project_type if --project-assays was not provided!')
		sys.exit()
	args.project_type = '-'.join(sorted(args.project_assays))

def get_project_assays_from_type():
	if args.project_type is None:
		print('cannot get project assays if --project-type was not provided!')
		sys.exit()
	args.project_assays = sorted(args.project_type.split('-'))

# ------------------------------------------------------------------------------------------------
# get information for genome used in the project
# ------------------------------------------------------------------------------------------------

def get_genome_parameters():
	genomes = {
		'mm10': {
			'organism': 'mus musculus',
			'assembly': 'mm10',
			'ensembl release': 98,
			'non-nuclear contigs': ['chrM'],
			'mitochondrial features': 'undefined'},
		'GRCh38': {
			'organism': 'homo sapiens',
			'assembly': 'GRCh38',
			'ensembl release': 98,
			'non-nuclear contigs': ['chrM'],
			'mitochondrial features': 'undefined'},
		'BDGP6.22': {
			'organism': 'drosophila melanogaster',
			'assembly': 'BDGP6.22',
			'ensembl release': 97,
			'non-nuclear contigs': ['mitochondrion_genome'],
			'mitochondrial features': 'undefined'},
		'GRCg6a': {
			'organism': 'gallus gallus',
			'assembly': 'GRCg6a',
			'ensembl release': 97,
			'non-nuclear contigs': ['MT'],
			'mitochondrial features': 'undefined'}}
	return(genomes.get(args.genome))

# ------------------------------------------------------------------------------------------------
# get the fastq directories for this lims id using data_path
# ------------------------------------------------------------------------------------------------

def get_fastq_paths_from_data_path():
	paths = glob.glob(args.fastq_paths_glob)
	paths.sort(key=natural_keys)
	return(paths)

# ------------------------------------------------------------------------------------------------
# read and filter a sample sheet, checking that required columns exist
# ------------------------------------------------------------------------------------------------

def read_design_file():
	return(read_and_check_file(args.design_file, ['sample_lims', 'sample_name', 'type', 'fastq_1']))

# ------------------------------------------------------------------------------------------------
# parse the sample sheet in `data` to guess library types
# ------------------------------------------------------------------------------------------------

def get_feature_types_to_search_terms():
	# dictionary of search terms in `sample_name` and their feature type
	return({
		'Gene Expression': ['^GEX_', '_GEX$', '_mxGEX$', '_snGEX'],
		'Chromatin Accessibility': ['^ATAC_', '_ATAC$', '_mxATAC$'],
		'Multiplexing Capture': ['_CMO$'],
		'VDJ-B': ['_B$', '_BCR$'],
		'VDJ-T': ['_T$', '_TCR$', '_TCR_$'],
		'Antibody Capture': ['_TSC$']})

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

	# check that every row had exactly one feature type regex match
	sample_sheet['total_feature_type_matches'] = sample_sheet[feature_types_to_search_terms.keys()].sum(axis=1)
	if sample_sheet['total_feature_type_matches'].gt(1).any():
		print(sample_sheet[sample_sheet['total_feature_type_matches'] > 1])
		print('some rows contained more than one feature type! check sample name regexes!')

	# check that every row has a feature type
	if (sample_sheet['library_type'].eq('unassigned')).any() and args.project_type != '10x-3prime':
		print(sample_sheet[sample_sheet['library_type'] == 'unassigned'])
		print('some rows could not be assigned a feature type! check sample name regexes!')

	# if all libraries are unassigned type and the project type is 10X-3prime, set the library type to Gene Expression
	if (sample_sheet['library_type'].eq('unassigned')).all() and args.project_type == '10x-3prime':
		print('all rows were unassigned but the project type is 10x-3prime; guessing that all libraries will be Gene Expression')
		sample_sheet['library_type'] = 'Gene Expression'

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

def get_dataset_indexes():
	indexes_root = '/flask/reference/Genomics'
	indexes_10x_root = os.path.join(indexes_root, '10x')
	indexes_10x_arc_root = os.path.join(indexes_10x_root, '10x_arc')
	indexes_10x_gex_root = os.path.join(indexes_10x_root, '10x_transcriptomes')
	indexes_10x_vdj_root = os.path.join(indexes_10x_root, '10x_transcriptomes')

	indexes = {
		'mm10': {
			'arc': os.path.join(indexes_10x_arc_root, 'refdata-cellranger-arc-mm10-2020-A-2.0.0'),
			'gex': os.path.join(indexes_10x_gex_root, 'refdata-gex-mm10-2020-A'),
			'vdj': os.path.join(indexes_10x_vdj_root, 'refdata-cellranger-vdj-GRCm38-alts-ensembl-7.0.0')},
		'GRCh38': {
			'arc': os.path.join(indexes_10x_arc_root, 'refdata-cellranger-arc-GRCh38-2020-A-2.0.0'),
			'gex': os.path.join(indexes_10x_gex_root, 'refdata-gex-GRCh38-2020-A'),
			'vdj': os.path.join(indexes_10x_vdj_root, 'refdata-cellranger-vdj-GRCh38-alts-ensembl-7.1.0')},
		'BDGP6.22': {
			'gex': os.path.join(indexes_10x_gex_root, 'Drosophila_melanogaster-release-97')},
		'GRCg6a': {
			'gex': os.path.join(indexes_10x_gex_root, 'Gallus_gallus-6.0-release-97')}}

	match regex_spm.fullmatch_in(args.project_type):
		case r'^10x(-|.*)-bcr(-|$).*'               : return({'index path': indexes.get(args.genome).get('gex'), 'vdj index path': indexes.get(args.genome).get('vdj')})
		case r'^10x(-|.*)-tcr(-|$).*'               : return({'index path': indexes.get(args.genome).get('gex'), 'vdj index path': indexes.get(args.genome).get('vdj')})
		case r'^10x-(3|5)prime(-|$).*' | '10x-flex' : return({'index path': indexes.get(args.genome).get('gex')})
		case '10x-multiome'                         : return({'index path': indexes.get(args.genome).get('arc')})
		case _:
			print("get_dataset_indexes: UNKNOWN PROJECT TYPE: {}".format(args.project_type))
			sys.exit()

def get_feature_types():
	assay_types = {
		'10x' : {
			'3prime'  : 'Gene Expression',
			'5prime'  : 'Gene Expression',
			'adt'     : 'Antibody Capture',
			'bcr'     : 'VDJ-B',
			'flex'    : 'Gene Expression',
			'hto'     : 'Multiplexing Capture',
			'multiome': ['Gene Expression', 'Chromatin Accessibility'],
			'plex'    : 'Gene Expression',
			'tcr'     : 'VDJ-T'}}

	match args.project_type:
		case '10x-multiome': assay_types['10x']['multiome']
		case _: list(set([assay_types.get('10x').get(assay) for assay in args.project_type.removeprefix('10x-').split('-')]))

def get_workflows():
	if args.project_type in ['10x-3prime', '10x-5prime']:
		return(['quantification/cell_ranger', 'seurat/prepare/cell_ranger'])
	elif '10x-multiome' == args.project_type:
		return(['quantification/cell_ranger_arc', 'seurat/prepare/cell_ranger_arc'])
	else:
		return(['quantification/cell_ranger_multi'])

def get_genome_files(dataset_index):
	match regex_spm.fullmatch_in(args.project_type):
		case r'^10x-(3|5)prime(-|$).*': return({
			'fasta file': os.path.join(dataset_index, 'fasta/genome.fa'),
			'fasta index file': os.path.join(dataset_index, 'fasta/genome.fa.fai'),
			'gtf file': os.path.join(dataset_index, 'genes/genes.gtf')})
		case r'^10x-multiome$': return({
			'fasta file': os.path.join(dataset_index, 'fasta/genome.fa'),
			'fasta index file': os.path.join(dataset_index, 'fasta/genome.fa.fai'),
			'gtf file': os.path.join(dataset_index, 'genes/genes.gtf.gz')})
		case _:
			print("get_genome_files: UNKNOWN PROJECT TYPE: {}".format(args.project_type))
			sys.exit()

# ------------------------------------------------------------------------------------------------
# get datasets parameter from sample to lims id dictionary
# ------------------------------------------------------------------------------------------------

def get_datasets(sample_lims_ids):
	dataset_barcodes = get_dataset_barcodes()
	for dataset,libraries in sample_lims_ids.items():
		if len(libraries) == 1:
			sample_lims_ids[dataset] = libraries.pop()
	return({k:{'description': k, 'limsid': sample_lims_ids[k]} | dataset_barcodes.get(k, {}) for k in sample_lims_ids})

# ------------------------------------------------------------------------------------------------
# get the barcode information, if relevant
# ------------------------------------------------------------------------------------------------

def read_barcode_file():
	return(read_and_check_file(args.barcodes_file, ['barcode', 'dataset']))

def get_dataset_barcodes():
	dataset_barcodes = {}
	if args.barcodes_file is None:
		return dataset_barcodes
	df = read_barcode_file()
	for index,row in df.iterrows():
		dataset_barcodes.update({(row['dataset']): dataset_barcodes.get(row['dataset'], []) + [row['barcode']]})
	return({k:{'barcode': dataset_barcodes[k][0] if len(dataset_barcodes[k]) == 1 else dataset_barcodes[k] } for k in dataset_barcodes})

# ------------------------------------------------------------------------------------------------
# get paths to set files, if relevant
# ------------------------------------------------------------------------------------------------

def get_set_files():
	set_files = {}
	if args.antibodies_file is not None: set_files.update({'adt set path': args.antibodies_file})
	if args.hto_file is not None: set_files.update({'hto set path': args.hto_file})
	if args.probes_file is not None: set_files.update({'probe set path': args.probes_file})
	return(set_files)

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

def read_and_check_file(path, important_columns):
	df = pandas.read_csv(path)
	for important_column in important_columns:
		if important_column not in df.columns:
			print('`{}` undefined in file {}!'.format(important_column, path))
			sys.exit()
		df = df[df[important_column].isnull() == False]
	return(df)

# ------------------------------------------------------------------------------------------------
# call these functions to get the parameters into a structure that can be written as yaml
# ------------------------------------------------------------------------------------------------

def main():
	# check and fill in command line arguments
	validate_arguments()

	# get parameters from args-dependent information
	workflows = get_workflows()
	genome = get_genome_parameters()
	fastq_paths = get_fastq_paths_from_data_path()
	dataset_indexes = get_dataset_indexes()
	feature_types = get_feature_types()
	library_types, sample_lims_ids = get_library_types()
	set_files = get_set_files()

	# get parameters dependent on the above variables
	datasets = get_datasets(sample_lims_ids)
	genome = genome | get_genome_files(dataset_indexes.get('index path'))

	# put the parameters together
	params = {
		'_project': {
			'lab': args.lab,
			'scientist': args.scientist,
			'lims id': args.lims_id,
			'babs id': 'unknown',
			'type': args.project_type,
			'assays': args.project_assays},
		'_genome': genome,
		'_defaults': {
			'fastq paths': fastq_paths,
			'feature types': library_types,
			'workflows': workflows,
			'feature identifiers': 'name'} | dataset_indexes | set_files,
		'_datasets': datasets}

	# write the above structure to a yaml file
	write_formatted_scamp_file(params)

main()
