---
title: {{.Name}}
layout: nf-workflow-doc

{{ if $workflow_doc := (getenv "SCAMP_DOC") -}}
	{{ os.ReadFile $workflow_doc -}}
{{ else -}}
	{{ print "SCAMP_DOC was not defined!" }}
{{ end -}}
---
