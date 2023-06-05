---
layout: nf-module-doc

{{ if $module_doc := (getenv "SCAMP_MODULE_DOC") -}}
	{{ os.ReadFile $module_doc -}}
{{ else -}}
	{{ print "SCAMP_MODULE_DOC was not defined!" }}
{{ end -}}

title: {{.Name}}
---

<!-- SCAMP_MODULE_DOC=scamp/modules/cell_ranger_arc/count/readme.yaml hugo new --kind module modules/cell_ranger_arc/count.md -->
<!-- find scamp/modules -name 'readme.yaml' | sed -e 's|^scamp/||' -e 's|/readme.yaml$||' | xargs -n 1 -I @ sh -c "SCAMP_MODULE_DOC=scamp/@/readme.yaml hugo new --kind doc-module --force @.md" -->
