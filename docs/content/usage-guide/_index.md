---
title: usage-guide
weight: 1

headingPre: |
  <script src="https://cdn.jsdelivr.net/npm/shepherd.js@10.0.1/dist/js/shepherd.min.js"></script>
  <link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/shepherd.js@10.0.1/dist/css/shepherd.css"/>
  <script src="/js/shepherd-tours.js"></script>
  <link rel="stylesheet" href="/css/shepherd.css"/>
---

[module docs]: {{< ref "/modules" >}}
[workflow docs]: {{< ref "/workflows" >}}

These notes illustrate how to setup an analysis using {scamp}. The structure of the parameters file and the command line usage is described. Detailed descriptions of the parameters can be found in the [modules][module docs] or [workflows][workflow docs] documentation.

<!--more-->

## Analysis configuration

A `parameters.yaml` file is used to described all aspects of a project and should serve as a record for parameters used in the pipeline. Passing Nextflow parameters on the command line via `--parameter` mechanism should be avoided; this would create an unexpected structure in the parameters object that may not be accounted for and prevent the pipeline launching.

The structure of `parameters.yaml` allows aspects of a project to be recorded alongside multiple analyses that can contain multiple datasets in a plain text and human readable format. `parameters.yaml` keys that being with underscores are reserved by {scamp} and should not be used in other keys. At the first level, the project (`_project`) and analysis stanzas are specified, the latter can have any name but should be reasonably filename-safe. Within analysis stanzas there are datasets which can also be freely (but sensibly) named.

## Example configuration file

{{% attachments title="Related files" /%}}

In this example for a scRNA-seq project, there are four datasets that will be quantified against mouse using the Cell Ranger mm10 reference from which Seurat objects will be prepared. To keep the file clear I tend to use symlinks in an `inputs` directory to other parts of the filesystem. The `inputs/primary_data` is a symlink to the ASF's outputs for this project and `inputs/10x_indexes` is a symlink to the communal 10X indexes resource.

{{< tabs title="hello." >}}
{{< tab name="scRNA-seq parameters.yaml" >}}
{{< shepherd_tour tour="scrna" lang="yaml" btn_msg="Take the input parameters tour" >}}
{{< /tab >}}

{{< tab name="snRNA+ATAC-seq parameters.yaml" >}}
{{< shepherd_tour tour="multiome" lang="yaml" btn_msg="Take the input parameters tour" >}}
{{< /tab >}}
{{< /tabs >}}

### Project description

{{% notice style="warning" %}}
feature types should be moved to be an analysis/dataset-level parameter
{{% /notice %}}

`_project` includes information about the project rather than parameters that should be applied to datasets.

Most of the information in this stanza can be extracted a path on Nemo and/or the LIMS.

The `genomes` stanza would be static across projects in most instances though the `ensembl release` is tied to any index against which the data is aligned or quantified (etc).

### Default project parameters

These parameters are defined here for convenience. They will be aggregated into every dataset-level stanza in all analysis stanzas in the project, without overriding parameters defined in analyses or datasets. Depending on the analysis stages, different keys will be expected. In this example we are going to quantify expression of a scRNA-seq dataset so we need to know where the FastQ files are in the file system. The paths (not files) are specified here. The `feature_identifiers` will be used when the {Seurat} object is created; this will use the gene names (rather than Ensembl identifiers) as feature names.

### Analysis stanzas

We can now specify multiple analyses to run different combinations of analysis stages. Analysis stanzas must have unique names and ideally not contain odd characters. {scamp} will _try_ to make the key directory-safe, however. Within each analysis stanza there is an optional `_default` and multiple dataset stanzas.

An analysis stanza typically contains a set of analysis stages, using the `stages` key. This curated list of keywords identifies which workflows should be applied to the dataset(s). In the example we specify two workflows: quantification by Cell Ranger and Seurat object creation. The order of the workflows is not important. The keywords to include can be found in the workflows documentation.

#### Default analysis parameters

As with the project-level default parameters, the parameters defined here are a convenience to avoid copy/paste into each dataset stanza. Parameters defined in a dataset will still override parameters defined here.

#### Dataset stanzas

A set of datasets are defined with unique names. The parameters defined here are the highest priority and override the analysis- and project-level `_defaults`. The name of a dataset is free but should be sensible, {scamp} will attempt to make the name directory-safe by replacing non `a-z`, `0-9` or `.` characters to underscores.

## Running the pipeline

{{% notice style="warning" title=" " icon=" " %}}
For now, the processes are __not__ containerised. All software, packages and libraries __must__ be available from the shell. The {scamp} conda environment provides Nextflow, R and all R packages.

{{< highlight bash "linenos=false" >}}
module load CellRanger-ARC/2.0.1
module load CellRanger/7.1.0
conda activate /nemo/stp/babs/working/barrinc/conda/envs/scamp
{{< /highlight >}}
{{% /notice %}}

Once the pipeline parameters are encoded in the parameters file, the pipeline can be launched:

{{< highlight bash "linenos=false" >}}
nextflow run ChristopherBarrington/scamp -r <release> -params-file inputs/parameters.yaml
{{< /highlight >}}

If you want to test you configuration file without running any real analysis, you can use:

{{< highlight bash "linenos=false" >}}
nextflow run ChristopherBarrington/scamp -r <release> -params-file inputs/parameters.yaml -stub-run -profile stub_run
{{< /highlight >}}

This will create empty files instead of analysing data but will produce errors if there is a configuration problem. Your analysis may still fail when it runs though!

Since {scamp} uses the parameters file for _all_ pipeline parameters, we cannot use the `--` approach to pass parameter options to {scamp}. This would effectively add additional stanzas to the configuration file. Depending on implementation, some parameters may be passed using `--_nextflow.<parameter>`.
