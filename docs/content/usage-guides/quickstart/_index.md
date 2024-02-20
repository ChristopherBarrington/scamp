---
title: quickstart
weight: 1
---

[scamp releases]: https://github.com/ChristopherBarrington/scamp/releases
[analysis configuration]: {{< ref "usage-guides/analysis-configuration" >}}

This is a quickstart guide that should get the pipeline running in most situations. A more detailed description of the structure of the parameters file and the command line usage is in the [analysis configuration][analysis configuration] section.

<!--more-->

## Running the pipeline

{{% notice style="warning" title=" " icon=" " %}}
For now, the processes are __not__ containerised. All software, packages and libraries __must__ be available from the shell. The {scamp} conda environment provides Nextflow, R and all R packages.

{{< highlight bash >}}
conda activate /nemo/stp/babs/working/barrinc/conda/envs/scamp
{{< /highlight >}}
{{% /notice %}}

{scamp} can be used to generate a best-guess parameters file. The file it creates is dependent on the sample sheet and directory structure on Nemo of the ASF's `data` directory in `babs/inputs`. The file it creates should be checked - especially for cases where multiple libraries contribute to individual samples, such as 10X multiome projects.

The following snippet will use the `guess_scamp_file.py` script that is included with {scamp} to find the data directory for the project and parse the accompanying design file. When the Conda environment is loaded, `NXF_HOME` is checked and set to a reasonable default if not defined. But really, `NXF_HOME` should be defined in your `.bashrc` alongside the other Nextflow environment variables. If you want to, a path under `working` could be used, for example `/nemo/stp/babs/working/${USER}/nextflow`. The `PATH` is then modified to include the `bin` for {scamp} so that the `guess_scamp_file.py` executable from {scamp} can be found in your shell.

Using `nextflow pull`, the most recent version of a pipeline can be downloaded into `NXF_HOME`. In the following chunk we direct a specific version of {scamp} to be downloaded using `-revision`. This is optional, but recommended to ensure you have the most-recent release available.

{{< tabs title="cache {scamp}" >}}
{{< tab title="with specific release" >}}
{{< highlight bash >}}
nextflow pull ChristopherBarrington/scamp -revision {{% getenv "SCAMP_TAG" %}}
{{< /highlight >}}
{{< /tab >}}
{{< tab title="most recent commit" >}}
{{< highlight bash >}}
nextflow pull ChristopherBarrington/scamp
{{< /highlight >}}
{{< /tab >}}
{{< /tabs >}}

`guess_scamp_file.py` includes a set of default parameters, which will need to be updated as we include new protocols. Example usage is shown below, where we indicate the genome that we want to use for the project, the LIMS ID under which the data was produced and the name of the output YAML file. For command line options, use `guess_scamp_file.py --help`.

For projects using dataset barcodes (10x Flex, Plex or HTO for example) a `barcodes.csv` file is required. This is a two-column CSV with "barcode" and "dataset" variables. Each row should be a unique barcode:dataset pair - if a dataset is labelled by multiple barcodes in the project, these should be represented on multiple rows. The "dataset" should match the name of the dataset in the project's design file (either in the ASF `data` directory or specified by `--design-file`). The barcodes and design files are parsed and joined together using the "barcode" as the key. Barcode information is not tracked in the LIMS and must be provided by the scientist.

A collection of assays can be included from which the project `type` can be defined. The project's assays is a curated set of keywords to define what types of data should be expected. For example, `--project-assays 3prime 10x` will be translated into `--project-type 10x-3prime`. A list of valid assay names can be found with `guess_scamp_file.py --help`. If `--project-type` is not provided, it is sought from `--project-assays` and vice versa. Only one of `--project-type` and `--project-assays` is required, but it is better to provide `--project-assays`; the assays in `--project-type` must be hyphen-separated and sorted alphabetically.

{{< tabs title="guess_scamp_file.py usage examples" >}}
{{< tab title="lims id" >}}
{{< highlight bash >}}
guess_scamp_file.py \
  --lims-id SC22034 \
  --genome mm10 \
  --project-assays 10x 3prime
{{< /highlight >}}
{{< /tab >}}

{{< tab title="data directory" >}}
{{< highlight bash >}}
guess_scamp_file.py \
  --data-path /nemo/stp/babs/inputs/sequencing/data/morisn/christopher.cooke/SC22034 \
  --genome mm10 \
  --project-assays 10x 3prime
{{< /highlight >}}
{{< /tab >}}

{{< tab title="lab, scientist and lims id" >}}
{{< highlight bash >}}
guess_scamp_file.py \
  --lab morisn \
  --scientist christopher.cooke \
  --lims-id SC22034 \
  --genome mm10 \
  --project-assays 10x 3prime
{{< /highlight >}}
{{< /tab >}}

{{< tab title="barcoded samples" >}}
{{< highlight bash >}}
guess_scamp_file.py \
  --lims-id SC22034 \
  --barcodes-file inputs/barcodes.csv \
  --project-assays 10x flex
{{< /highlight >}}
{{< /tab >}}

{{< tab title="help" >}}
{{< highlight bash >}}
guess_scamp_file.py --help
{{< /highlight >}}
{{< /tab >}}
{{< /tabs >}}

{{% notice style="warning" title=" " icon=" " %}}
Check the guessed parameters file! Pay particular attention to the LIMS IDs associated to dataset, the feature types and sample names!
{{% /notice %}}

The parameters in the guessed `scamp_file.yaml` should now be checked, the values may need to be corrected and/or amended or new information included. For example, certain samples may need to be removed or different analysis workflows my be required. Examples of analysis parameters files can be found in the [analysis configuration][analysis configuration] post.

Once the pipeline parameters are encoded in the parameters file, the pipeline can then be launched using a [specific release][scamp releases] such as `{{% getenv "SCAMP_TAG" %}}` or the current version using `main`. Using a specific tag is recommended for reproducibility.

If you want to test you configuration file without running any real analysis, you can run Nextflow in `stub-run` mode:

{{< tab title="bash" >}}
{{< highlight bash >}}
nextflow run ChristopherBarrington/scamp -revision {{% getenv "SCAMP_TAG" %}} \
  -stub-run -profile stub_run \
  --scamp_file scamp_file.yaml
{{< /highlight >}}
{{< /tab >}}

This will create empty files instead of analysing data but will produce errors if there is a configuration problem. Your analysis may still fail when it runs though! Once you are confident, you can run the pipeline:

{{< tab title="bash" >}}
{{< highlight bash >}}
nextflow run ChristopherBarrington/scamp -revision {{% getenv "SCAMP_TAG" %}} \
  --scamp_file scamp_file.yaml
{{< /highlight >}}
{{< /tab >}}

This should now start the pipeline and show the processes being run for each of the analysis `workflows` detailed in your configuration file.
