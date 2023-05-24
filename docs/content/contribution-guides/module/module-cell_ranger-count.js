
let steps = new Map(Object.entries({
	"process" : {
		target: "main-nf-1",
		text: "The process definition"},
	"inputs" : {
		target: "main-nf-8",
		text: "Expected input channels"},
	"outputs" : {
		target: "main-nf-15",
		text: "Output channels are the files, directories, and/or variables created in this task that should be made available or published by the pipeline."},
	"script" : {
		target: "main-nf-25",
		text: "Any parsing/wrangling and execution of a script is here."},
	"resources" : {
		target: "main-nf-4",
		text: "Default resource requirements, for example <code>cpus</code> requests 8 CPU cores, requested for the process."}}));
