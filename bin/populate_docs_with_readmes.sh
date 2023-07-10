#! /bin/env bash

cd docs || exit

find scamp/modules -name 'readme.yaml' |
	sed -e 's|^scamp/||' -e 's|/readme.yaml$||' |
	xargs -I @ sh -c "SCAMP_DOC=scamp/@/readme.yaml hugo new --kind doc-module --force @.md"

find scamp/workflows -name 'readme.yaml' |
	sed -e 's|^scamp/||' -e 's|/readme.yaml$||' |
	xargs -I @ sh -c "SCAMP_DOC=scamp/@/readme.yaml hugo new --kind doc-workflow --force @.md"

find scamp/utilities -name 'main.yaml' |
	sed -e 's|^scamp/||' -e 's|/main.yaml$||' |
	xargs -I @ sh -c "SCAMP_DOC=scamp/@/main.yaml hugo new --kind doc-utility --force @.md"

find content/{modules,workflows,utilities} -mindepth 0 -type d |
	xargs -I @ sh -c "hugo new --kind docs-group --force @/_index.md"

SCAMP_DOC=scamp/user-parameters.yaml hugo new --kind doc-user-parameters --force usage-guides/user-parameters/_index.md

if [[ $OSTYPE == 'darwin'* ]]; then
	sed -i .sed 's/weight: /weight: 101/' content/modules/_index.md
	sed -i .sed 's/weight: /weight: 102/' content/workflows/_index.md
	sed -i .sed 's/weight: /weight: 103/' content/utilities/_index.md
	rm content/{modules,workflows,utilities}/_index.md.sed

else
	sed -i 's/weight: /weight: 101/' content/modules/_index.md
	sed -i 's/weight: /weight: 102/' content/workflows/_index.md
	sed -i 's/weight: /weight: 103/' content/utilities/_index.md
fi
