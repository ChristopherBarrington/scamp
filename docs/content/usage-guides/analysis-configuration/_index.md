---
title: scamp configuration
weight: 5
---

[module docs]: {{< ref "/modules" >}}
[workflow docs]: {{< ref "/workflows" >}}

These notes illustrate how to configure an analysis using {scamp}. Detailed descriptions of the parameters can be found in the [modules][module docs] or [workflows][workflow docs] documentation.

<!--more-->

## Analysis configuration

A parameters YAML file is used to described all aspects of a project and should serve as a record for parameters used in the pipeline. It will be passed to Nextflow as a parameter using `--scamp_file`.

The structure of parameters file allows aspects of a project to be recorded alongside analysis parameters that can be specified for multiple datasets in a plain text and human-readable format. Parameter keys that begin with underscores are reserved by {scamp} and should not be used in other keys. At the first level, the project (`_project`), genome (`_genome`), common dataset parameters (`_defaults`) and dataset (`_dataset`) stanzas are specified. Within the datasets stanza, datasets can be freely (but sensibly) named.

## Example configuration file

{{% attachments title="Related files" /%}}

In this example for a scRNA-seq project, there are four datasets that will be quantified against mouse using the Cell Ranger mm10 reference from which Seurat objects will be prepared. To keep the file clear I have assumed symlinks are available in an `inputs` directory to other parts of the filesystem. The `inputs/primary_data` is a symlink to ASF's outputs for this project and `inputs/10x_indexes` is a symlink to the communal 10X indexes resource.

{{< tabs title="Example parameters" >}}
{{< tab title="scRNA-seq" >}}
{{< shepherd_tour tour="scrna" lang="yaml" btn_msg="Take a tour of the input parameters" >}}
{{< /tab >}}

{{< tab title="snRNA+ATAC-seq" >}}
{{< shepherd_tour tour="multiome" lang="yaml" >}}
{{< /tab >}}
{{< /tabs >}}

`_project` includes information about the project rather than parameters that should be applied to datasets. Most of the information in this stanza can be extracted from a path on Nemo and/or the LIMS.

The `_genome` stanza is static across most projects though the `ensembl release` is tied to any index against which the data is aligned or quantified (etc).

`_defaults` describes parameters that will be aggregated into every dataset in the `_datasets` stanza of the project, with the dataset-level parameter taking precedence. (So we don't have a big copy/paste list of parameters). Depending on the analysis stages, different keys will be expected. In this example we are going to quantify expression of a scRNA-seq dataset so we need to know where the FastQ files are in the file system. The paths (not files) are specified here with `fastq paths`. The `feature_identifiers` will be used when the Seurat object is created; specifying "names" will use the gene names (rather than Ensembl identifiers) as feature names. The default parameters stanza typically contains a set of analysis stages, using the `stages` key. This curated list of keywords identifies which workflows should be applied to the dataset(s). In the example we specify two workflows: quantification by Cell Ranger and Seurat object creation. The order of the workflows is not important. The keywords to include can be found in the [workflows documentation][workflow docs].

Each dataset is described in `_datasets`. Dataset stanzas must have unique names and ideally not contain odd characters. {scamp} will _try_ to make the key directory-safe, however.
