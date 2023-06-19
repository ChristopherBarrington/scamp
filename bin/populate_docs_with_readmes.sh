#! /bin/env bash

cd docs || exit

find scamp/modules -name 'readme.yaml' |
	sed -e 's|^scamp/||' -e 's|/readme.yaml$||' |
	xargs -n 1 -P 4 -I @ sh -c "SCAMP_DOC=scamp/@/readme.yaml hugo new --kind doc-module --force @.md"

find scamp/workflows -name 'readme.yaml' |
	sed -e 's|^scamp/||' -e 's|/readme.yaml$||' |
	xargs -n 1 -P 4 -I @ sh -c "SCAMP_DOC=scamp/@/readme.yaml hugo new --kind doc-workflow --force @.md"

find scamp/utilities -name 'main.yaml' |
	sed -e 's|^scamp/||' -e 's|/main.yaml$||' |
	xargs -n 1 -P 4 -I @ sh -c "SCAMP_DOC=scamp/@/main.yaml hugo new --kind doc-utility --force @.md"

find content/{modules,workflows,utilities} -mindepth 0 -type d |
	xargs -n 1 -P 4 -I @ sh -c "hugo new --kind docs-group --force @/_index.md"
