#! /bin/env bash

(cd docs
find scamp/modules -name 'readme.yaml' |
	sed -e 's|^scamp/||' -e 's|/readme.yaml$||' |
	xargs -n 1 -I @ sh -c "SCAMP_MODULE_DOC=scamp/@/readme.yaml hugo new --kind doc-module --force @.md"

find content/modules -mindepth 0 -type d |
	xargs -n 1 -I @ sh -c "hugo new --kind docs-group --force @/_index.md"
)
