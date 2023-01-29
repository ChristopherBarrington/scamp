//		// get a list of maps of {sample name, fastq path, fastq path + sample, fastq path + sample + regex}
//		fastq_paths_and_regexes = filtered_stage_parameters
//			.collect{x -> 
//				[x.get('fastq paths'), x.get('samples')]
//					.combinations()
//					.collect{[it[1], it[0], it.join('/')]} // <sample> <fastq path> <fastq path/sample>
//					.collect{it + [it.getAt(2)+'_S*_L*_R1_001.fastq.gz']}}
//			.flatten()
//			.collate(4) // hard coded number of elements in the tuples!
//			.unique()
//			.collect{make_map(it, ['sample name', 'root path', 'sample root', 'path regex'])}
//
//		// get a list of fastq file sample roots found in the unique set of fastq paths using the regular expression
//		channel
//			.empty()
//			.set{fastq_files}
//		
//		if(fastq_paths_and_regexes.size() > 0)
//			channel
//				.fromPath(fastq_paths_and_regexes.collect{it.get('path regex')}.unique(), glob: true, type: 'file', hidden: false, maxDepth: 1, followLinks: true, relative: false, checkIfExists: false)
//				.map{file_path -> file_path.toString() - ~/_S[0-9]+_L[0-9]+_R1_001.fastq.gz/}
//				.unique()
//				.map{['sample root':it]}
//				.dump(tag: 'cell_ranger_arc:fastq_files', pretty: true)
//				.set{fastq_files}
//
//		// get sample feature type from parameters file
//		feature_types = get_feature_types()
//
//		// mix the results together and filter so make sure the dataset and sample match
//		fastq_files
//			.combine(channel.from(fastq_paths_and_regexes))
//			.combine(channel.from(feature_types))
//			.filter{check_for_matching_key_values(it, 'sample root') &&
//			        check_for_matching_key_values(it, 'sample name')}
//			.map{concatenate_maps_list(it).subMap(['root path', 'sample name', 'feature type'])} // flatten??
//			.map{rename_map_keys(it, ['root path', 'sample name', 'feature type'], ['fastqs', 'sample', 'library_type'])}
//			.dump(tag: 'cell_ranger_arc:sample_sheet_data', pretty: true)
//			.set{sample_sheet_data}
//
//		// write the sample sheet file and get the path in a new channel
//		sample_sheet_data
//			.first()
//			.map{it.keySet().join(',')}
//			.collectFile(name: 'header.csv', newLine: true)
//			.concat(sample_sheet_data.map{it.values().join(',')}.collectFile(name: 'data.csv', newLine: true, sort: true))
//			.collectFile(name: 'libraries.csv', keepHeader:false, newLine: false, sort: 'index')
//			.first()
//			.dump(tag: 'cell_ranger_arc:sample_sheet_file', pretty: true)
//			.set{sample_sheet_file}