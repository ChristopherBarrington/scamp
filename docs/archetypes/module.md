---
layout: nf-module-doc

{{ if $module_doc := (getenv "SCAMP_MODULE_DOC") -}}
	{{ os.ReadFile $module_doc -}}
{{ else -}}
	{{ print "SCAMP_MODULE_DOC was not defined!" }}
{{ end -}}
---

<!-- SCAMP_MODULE_DOC=scamp/modules/cell_ranger_arc/count/readme.yaml hugo new --kind module modules/cell_ranger_arc/count/_index.md -->
