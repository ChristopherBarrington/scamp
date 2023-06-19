// print a text file to the screen

def print_pipeline_title(dirname='pipeline_logos', padh=10, padv=1) {
	println('\n'.multiply(padv))
	file([projectDir, 'assets', dirname].join('/'))
		.listFiles()
		.findAll{it.toString().endsWith('.txt')}
		.shuffled()
		.first()
		.eachLine{println(' '.multiply(padh).plus(it))}
	println('\n'.multiply(padv))
}
