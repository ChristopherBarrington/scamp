---
title: {{.Name}}
layout: nf-module-doc

{{ if $module_doc := (getenv "SCAMP_DOC") -}}
	{{ os.ReadFile $module_doc -}}
{{ else -}}
	{{ print "SCAMP_DOC was not defined!" }}
{{ end -}}
---
