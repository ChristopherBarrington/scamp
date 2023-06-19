---
title: {{.Name}}
layout: nf-workflow-doc

{{ if $doc := (getenv "SCAMP_DOC") -}}
	{{ os.ReadFile $doc -}}
{{ else -}}
	{{ print "SCAMP_DOC was not defined!" }}
{{ end -}}
---
