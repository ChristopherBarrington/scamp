---
layout: nf-module-doc

{{ if $module_doc := (getenv "SCAMP_MODULE_DOC") -}}
	{{ os.ReadFile $module_doc -}}
{{ else -}}
	{{ print "SCAMP_MODULE_DOC was not defined!" }}
{{ end -}}
---

<!-- SCAMP_MODULE_DOC=scamp/modules/cell_ranger_arc/count/readme.yaml hugo new --kind module modules/cell_ranger_arc/count/_index.md -->
<!-- find scamp/modules -name 'readme.yaml' | sed -e 's|^scamp/||' -e 's|/readme.yaml$||' | xargs -n 1 -I @ sh -c "SCAMP_MODULE_DOC=scamp/@/readme.yaml hugo_extended_0.110.0 new --kind module --force --quiet @.md" -->
