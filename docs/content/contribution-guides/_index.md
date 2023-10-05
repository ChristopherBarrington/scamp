---
title: "contribution guides"
weight: 2
---

These guides will hopefully help you to add features into {scamp}. New features can be added by writing modules, these are the basic building blocks around which a workflow is written. A workflow consists of several processes that are used in concert to achieve something. Workflows may be though of as independent pipelines, in {scamp} we can chain multiple pipelines together to provide flexibility for the analysis.

Writing a module requires a script (of any language) to be written alongside a simple Nextflow process definition. Together these define how the input data is processed and what is produced as output. Each module is documented and so it is a self-contained unit.

A workflow can include multiple modules and is where the management of parameters occurs. In the workflow, user parameters are manipulated and augmented with the output of processes so that successive processes can be managed to complete an analysis. Workflows could be nested into related topics, with workflows being able to initiate (sub)workflows (etc). Each workflow is documented alongside its Nextflow file.

{{% children
	containerstyle="ul"
	style="li"
	showhidden=true
	description=true
	depth=99
	sort="weight" %}}
