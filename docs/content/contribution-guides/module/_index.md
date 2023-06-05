---
title: module
weight: 1

headingPre: |
  <script src="https://cdn.jsdelivr.net/npm/shepherd.js@10.0.1/dist/js/shepherd.min.js"></script>
  <link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/shepherd.js@10.0.1/dist/css/shepherd.css"/>
  <script src="/js/shepherd-tours.js"></script>
  <link rel="stylesheet" href="/css/shepherd.css"/>
---

Modules represent specific steps of a pipeline that can be reused in multiple instances. A module should be written to be generic and not specifically tied to a pipeline, workflow or subworkflow (etc). Each module performs a specific task and usually includes only a few different programs.

<!--more-->

[nf docs process]: https://www.nextflow.io/docs/latest/process.html
[nf docs process inputs]: https://www.nextflow.io/docs/latest/process.html#input
[nf docs process outputs]: https://www.nextflow.io/docs/latest/process.html#outputs
[nf docs process script]: https://www.nextflow.io/docs/latest/process.html#script
[nf docs process stub]: https://www.nextflow.io/docs/latest/process.html#stub
[nf docs process directives]: https://www.nextflow.io/docs/latest/process.html#directives

[docs scamp modules]: {{< ref "/modules" >}}

{{< notice style="tip" title=" " icon=" " >}}
Working modules can be written independently from their inclusion in a pipeline, so do not worry about learning Nextflow if you don't want to - you can write the module scripts that can be wrapped in Nextflow later.
{{< /notice >}}

A suggested module structure could be as follows. The example module is called "a_new_module" and contains one subdirectory and two files. These will be described more thoroughly below. Briefly, the `main.nf` file is where the Nextflow process is defined, this is the part of the module that controls the execution of the `main.sh` script (in this example). The `stub.sh` is an optional file that can be used to generate placeholder files or output so that a pipeline can be tested without taking the time to analyse any data. The `readme.yaml` will be used to create documentation for this website.

{{< highlight "linenos=false" >}}
a_new_module/
|-- main.nf
|-- readme.yaml
`-- templates
    |-- main.sh
    `-- stub.sh
{{< /highlight >}}

The following are suggestions. This is the way that I have been writing modules. But there is flexibility, if you don't like the way I have written the R script below you don't have to do it the same way!

## Nextflow process

[{{< icon icon="external-link-alt" >}} Nextflow's process documentation][nf docs process]

The process defines the context in which a processing step is executed on a set of inputs; a single process can become multiple tasks where each task has a different set of input parameters for the process.

An example process "complicated_analysis" is defined below, in the `main.nf` file. The _really_ important parts are the `input`, `output` and `script` stanzas.

The [`inputs` to a process][nf docs process inputs] are passed as channels from the Nextflow pipeline. The order and type of channel is important. The definitions here must be adhered to in the pipeline. In this example, there are four inputs: `opt`, `tag`, `sample` and `db`. Their types are specified as either `val` or `file`. A `val` is a value which can be substituted into the script. The `file` will be a symlink to the target named, in this case, "db".

For {scamp} processes, the `opt` and `tag` inputs should be used universally. The `opt` channel is a `map` of key value pairs that can be accessed by the configuration file, allowing pipeline parameters that are not necessarily used in the process to be accessed outside the task, and used to track input parameters in output channels. But beware that only variables that affect the process's execution should be included because they could invalidate the cache. The `tag` is a string that will be added to the Nextflow output log to identify an individual task.

The [`outputs` of a process][nf docs process outputs] are the files or variables produced by the script. The "complicated_analysis" module emits four output channels: the `opt` without modification from it's input, two `yaml` files to track the software versions and task parameters and the analysis output file: `output.file`. These are emitted to the pipeline in channels named `opt`, `task`, `versions` and `output`.

For {scamp} processes the `opt`, `task` and `versions` should be used. The `task` and `versions` may be used in the future to compose markdown reports.

The [`script` stanza][nf docs process script] defines what analysis actually happens. I favour using templates here so that the scripts are kept separate from Nextflow. In this example, if the user has provided the [`-stub-run` argument][nf docs process stub] when invoking the pipeline, the `stub.sh` script is executed, otherwise it is `main.sh`.

Other [Nextflow directives][nf docs process directives] can be included but may not be completely relevant in the context of a module. For example, using `publishDir` should be the choice of the pipeline creator so may not be sensible to include here. Directives included here can be overridden by a suitable configuration file, however. In this case we include some resource requests - `cpus`, `memory` and `time` - but no execution method (eg `SLURM`) which should be defined at execution by the user.

{{< tabs >}}
{{< tab name="main.nf" >}}
{{< shepherd_tour tour="nextflow_process" lang="groovy" btn_msg="Take the Nextflow process tour" >}}
{{< /tab >}}
{{< /tabs >}}

## Executable script

[{{< icon icon="external-link-alt" >}} Nextflow's script documentation][nf docs process script]

Nextflow is language agnostic and so long as the interpreter is available in the task's `PATH` the script should run. These scripts can be tested outside Nextlfow with equivalent parameters passed as environment variables, for example. Containers can be used and should be included in the directives of the process.

In this example there are two programs being used to create an output file from two inputs. The first tool uses the task's `sample` variable and the `db` file from the `inputs`. The value of `sample` is interpolated into the script by `$sample`. For `db`, a symlink is created, in the work directory of the task, between the target file and "db" so we can specify `db` in the script as if it were that file, irrespective of its location in the filesystem.

Once `analysis_tool` has completed its work the intermediate output file is parsed and `output.file` is written. Nextflow will provide this file to the pipeline since it was listed in the `output` stanza for the process.

The `task.yaml` and `versions.yaml` files may be used in the future so that task-specific information can be included in reports.

An R script could be used here too, specifying `Rscript` instead of `bash` in the shebang line. Nextlfow variables are similarly interpolated into the script though so be wary when accessing lists. Writing the `task` and `versions` can be taken care of using the {scampr} package.

{{% notice style="warning" title=" " icon=" " %}}
Nextflow will interpolate variables using `$variable` so any scripts using `$` may have unexpected behaviour. Where possible use non-dollar alternatives or delimit the symbol.
{{% /notice %}}

{{< tabs >}}
{{< tab name="main.sh" >}}
{{< shepherd_tour tour="template_bash" lang="bash" btn_msg="Take the bash script tour" >}}
{{< /tab >}}
{{< tab name="main.Rscript" >}}
{{< shepherd_tour tour="template_rscript" lang="r" btn_msg="Take the R script tour" >}}
{{< /tab >}}
{{< /tabs >}}

## Stub script

The optional `stub.sh` is an alternative script that can be executed when the user invokes `-stub-run`. The idea of this script is to create the output files expected by the pipeline without expending computational resource. In this way we can test how processes and channels interact in the pipeline without conjuring test data or worrying about cache validity.

The example below simply uses `touch` to create output files with no content.

{{< tabs >}}
{{< tab name="stub.sh" >}}
{{< shepherd_tour tour="template_stub" lang="bash" btn_msg="Take the stub script tour" >}}
{{< /tab >}}
{{< /tabs >}}

## Documentation

Each module should be documented using the `readme.yaml` file. This file will be used to populate the [module documentation][docs scamp modules] on this website.

{{< tabs >}}
{{< tab name="readme.yaml" >}}
{{< shepherd_tour tour="readme" lang="yaml" >}}
{{< /tab >}}
{{< /tabs >}}
