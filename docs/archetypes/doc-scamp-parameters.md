---
title: user-configurable parameters
layout: scamp-parameters-summary-doc
weight: 10

scamp_parameters:
{{ if $doc := (getenv "SCAMP_DOC") -}}
	{{ os.ReadFile $doc | replaceRE "^" "  " | replaceRE "\n" "\n  " | strings.TrimSuffix "  " -}}
{{ else -}}
	{{ print "SCAMP_DOC was not defined!" }}
{{ end -}}
---

[quickstart]: {{< ref "usage-guides/quickstart" >}}
[analysis configuration]: {{< ref "usage-guides/analysis-configuration" >}}

This post contains a more-detailed description of the parameters that may be defined in a `scamp-file`. Some parameters are required, others may be defined from defaults while some may be provided by upstream {scamp} processes.

<!--more-->
