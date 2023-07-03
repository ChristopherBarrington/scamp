---
title: usage guide
weight: 1

headingPre: |
  <script src="https://cdn.jsdelivr.net/npm/shepherd.js@10.0.1/dist/js/shepherd.min.js"></script>
  <link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/shepherd.js@10.0.1/dist/css/shepherd.css"/>
  <script src="/js/shepherd-tours.js"></script>
  <link rel="stylesheet" href="/css/shepherd.css"/>
---

[module docs]: {{< ref "/modules" >}}
[workflow docs]: {{< ref "/workflows" >}}
[scamp releases]: https://github.com/ChristopherBarrington/scamp/releases

These notes illustrate how to setup an analysis using {scamp}. The structure of the parameters file and the command line usage is described. Detailed descriptions of the parameters can be found in the [modules][module docs] or [workflows][workflow docs] documentation.

<!--more-->

## Analysis configuration

A `parameters.yaml` file is used to described all aspects of a project and should serve as a record for parameters used in the pipeline. Passing Nextflow parameters on the command line via `--parameter` mechanism should be avoided; this would create an unexpected structure in the parameters object that may not be accounted for and prevent the pipeline launching.

The structure of `parameters.yaml` allows aspects of a project to be recorded alongside multiple analyses that can contain multiple datasets in a plain text and human readable format. `parameters.yaml` keys that being with underscores are reserved by {scamp} and should not be used in other keys. At the first level, the project (`_project`) and analysis stanzas are specified, the latter can have any name but should be reasonably filename-safe. Within analysis stanzas there are datasets which can also be freely (but sensibly) named.

## Example configuration file

{{% attachments title="Related files" /%}}

In this example for a scRNA-seq project, there are four datasets that will be quantified against mouse using the Cell Ranger mm10 reference from which Seurat objects will be prepared. To keep the file clear I tend to use symlinks in an `inputs` directory to other parts of the filesystem. The `inputs/primary_data` is a symlink to the ASF's outputs for this project and `inputs/10x_indexes` is a symlink to the communal 10X indexes resource.

{{< tabs title="Example parameters" >}}
{{< tab title="scRNA-seq" >}}
{{< shepherd_tour tour="scrna" lang="yaml" btn_msg="Take the input parameters tour" >}}
{{< /tab >}}

{{< tab title="snRNA+ATAC-seq" >}}
{{< shepherd_tour tour="multiome" lang="yaml" >}}
{{< /tab >}}
{{< /tabs >}}

### Project description

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

{{< highlight bash >}}
module load CellRanger-ARC/2.0.1
module load CellRanger/7.1.0
conda activate /nemo/stp/babs/working/barrinc/conda/envs/scamp
{{< /highlight >}}
{{% /notice %}}

{scamp} can be used to generate a best-guess parameters file. The file it creates is dependent on the sample sheet and directory structure on Nemo of the ASF's `data` directory in `babs/inputs`. The file it creates should be checked - especially for cases where multiple libraries contribute to individual samples, such as 10X multiome projects.

(It is currently a bit of a faff though it may move into a container) The following snippet will use the `guess_scamp_file.py` script that is included in {scamp} to find the directory for the project and parse the accompanying design file. First, {scamp} must be pulled and its `bin` added to your `PATH`. For command line options, use `guess_scamp_file.py --help`. The script includes a set of default parameters, which will need to be updated as we include new protocols.

{{< tab title="bash" >}}
{{< highlight bash >}}
export PATH=$PATH:$NXF_HOME/assets/ChristopherBarrington/scamp/bin

nextflow pull ChristopherBarrington/scamp -revision main
guess_scamp_file.py --genome mm10 --lims-id SC22051 --output-file scamp-file.yaml
{{< /highlight >}}
{{< /tab >}}

{{% notice style="warning" title=" " icon=" " %}}
Check the guessed parameters file! Pay particular attention to the LIMS IDs associated to dataset, the feature types and sample names!
{{% /notice %}}

Once the pipeline parameters are encoded in the parameters file, the pipeline can be launched using a [specific release][scamp releases] such as `23.07.02` or the current version using `main`. Using a specific tag is recommended for reproducibility.

{{< tab title="bash" >}}
{{< highlight bash >}}
nextflow run ChristopherBarrington/scamp -revision 23.07.02 \
  --scamp-file scamp-file.yaml
{{< /highlight >}}
{{< /tab >}}

If you want to test you configuration file without running any real analysis, you can use:

{{< tab title="bash" >}}
{{< highlight bash >}}
nextflow run ChristopherBarrington/scamp -revision 23.07.02 \
  -stub-run -profile stub_run \
  --scamp-file scamp-file.yaml
{{< /highlight >}}
{{< /tab >}}

This will create empty files instead of analysing data but will produce errors if there is a configuration problem. Your analysis may still fail when it runs though!
