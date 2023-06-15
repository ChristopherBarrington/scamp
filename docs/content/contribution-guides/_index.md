---
title: "contribution guides"
weight: 2
---

These guides will hopefully help you to add features into {scamp}. New features can be added by writing modules, these are the basic building blocks around which a workflow is written. A workflow consists of several processes that are used in concert to achieve something. Workflows may be though of as independent pipelines, in {scamp} we can chain multiple pipelines together to provide flexibility for the analysis.

Writing a module requires a script (of any language) to be written alongside a simple Nextflow process definition. Together these define how the input data is processed and what is produced as output. Each module is documented and so it is a self-contained unit.

A workflow can include multiple modules and is where the management of parameters occurs. In the workflow, user parameters are manipulated and augmented with the output of processes so that successive processes can be managed to complete an analysis. Workflows could be nested into related topics, with workflows being able to initiate subworkflows (etc). Each workflow is documented alongside its Nextflow file.

{{% children
	containerstyle="ul"
	style="li"
	showhidden=true
	description=true
	depth=99
	sort="weight" %}}

Morbi quis tortor ut neque condimentum malesuada. Donec gravida lorem in enim dapibus posuere. Vestibulum non congue augue, nec efficitur ipsum. Aenean in nunc sed sem commodo suscipit. Nam rutrum sem a ante gravida porttitor. Integer quis tellus et felis pellentesque feugiat et quis ante. In lorem justo, aliquet eget molestie id, consectetur eleifend metus. Vestibulum euismod enim ipsum, sed viverra purus consequat non. Proin id luctus mi. Cras consectetur volutpat purus a aliquam. Nullam ut dapibus odio, placerat ornare erat. Duis interdum ipsum et enim rhoncus, at posuere velit rhoncus. Suspendisse nec eros in mi aliquam imperdiet. Mauris ut lectus vel tortor commodo pellentesque. Phasellus suscipit tellus felis, sit amet ornare eros sodales vitae.
