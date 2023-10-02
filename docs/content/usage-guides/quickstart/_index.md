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

(It is currently a bit of a faff though it may move into a container)

The following snippet will use the `guess_scamp_file.py` script that is included in {scamp} to find the data directory for the project and parse the accompanying design file. First, we need to ensure that the Nextflow environment is configured with `NXF_HOME` set to the path that Nextflow uses to store downloaded pipelines (and other things). The following snippet will check if `NXF_HOME` is defined already and assign it to a reasonable default if it is undefined. But really, `NXF_HOME` should be defined in your `.bashrc` alongside the other Nextflow environment variables. If you want to, a path under `working` could be used, for example `/nemo/stp/babs/working/${USER}/nextflow`.

{scamp} must be pulled and its `bin` added to your `PATH` so that the `guess_scamp_file.py` executable can be found in your shell. In the following chunk, {scamp} is downloaded into `NXF_HOME` and the path to {scamp} executables added to the `PATH`.

{{< tab title="bash" >}}
{{< highlight bash >}}
if [[ -n ${NXF_HOME} ]]; then
  export NXF_HOME=/nemo/project/home/${USER}/.nextflow
fi

nextflow pull ChristopherBarrington/scamp -revision {{% getenv "SCAMP_TAG" %}}
export PATH=$PATH:$NXF_HOME/assets/ChristopherBarrington/scamp/bin
{{< /highlight >}}
{{< /tab >}}

`guess_scamp_file.py` includes a set of default parameters, which will need to be updated as we include new protocols. Example usage is shown below, where we indicate the genome that we want to use for the project, the LIMS ID under which the data was produced and the name of the output YAML file. For command line options, use `guess_scamp_file.py --help`.

{{< tabs title="guess_scamp_file.py usage examples" >}}

{{< tab title="lims id" >}}
{{< highlight bash >}}
guess_scamp_file.py \
  --lims-id SC22034 \
  --genome mm10 \
  --output-file scamp_file.yaml
{{< /highlight >}}
{{< /tab >}}

{{< tab title="data directory" >}}
{{< highlight bash >}}
guess_scamp_file.py \
  --data-path /nemo/stp/babs/inputs/sequencing/data/morisn/christopher.cooke/SC22034 \
  --genome mm10 \
  --output-file scamp_file.yaml
{{< /highlight >}}
{{< /tab >}}

{{< tab title="lab, scientist and lims id" >}}
{{< highlight bash >}}
guess_scamp_file.py \
  --lab morisn \
  --scientist christopher.cooke \
  --lims-id SC22034 \
  --genome mm10 \
  --output-file scamp_file.yaml
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

The parameters in the guessed `scamp_file.yaml` should now be checked, the values may need to be corrected and/or amended or new information included. For example, certain samples may need to be removed or different analysis stages my be required. Examples of analysis parameters files can be found in the [analysis configuration][analysis configuration] post.

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

This should now start the pipeline and show the processes being run for each of the analysis `stages` detailed in your configuration file.
