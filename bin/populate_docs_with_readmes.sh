#! /bin/env bash

cd docs || exit

find scamp/modules -name 'readme.yaml' |
	sed -e 's|^scamp/||' -e 's|/readme.yaml$||' |
	xargs --max-args 1 sh -c "SCAMP_DOC=scamp/@/readme.yaml hugo new --kind doc-module --force @.md"

find scamp/workflows -name 'readme.yaml' |
	sed -e 's|^scamp/||' -e 's|/readme.yaml$||' |
	xargs --max-args 1 sh -c "SCAMP_DOC=scamp/@/readme.yaml hugo new --kind doc-workflow --force @.md"

find scamp/utilities -name 'main.yaml' |
	sed -e 's|^scamp/||' -e 's|/main.yaml$||' |
	xargs --max-args 1 sh -c "SCAMP_DOC=scamp/@/main.yaml hugo new --kind doc-utility --force @.md"

find content/{modules,workflows,utilities} -mindepth 0 -type d |
	xargs --max-args 1 sh -c "hugo new --kind docs-group --force @/_index.md"

sed -i 's/weight: /weight: 101/' content/modules/_index.md
sed -i 's/weight: /weight: 102/' content/workflows/_index.md
sed -i 's/weight: /weight: 103/' content/utilities/_index.md

# sed -i .sed 's/weight: /weight: 101/' content/modules/_index.md
# sed -i .sed 's/weight: /weight: 102/' content/workflows/_index.md
# sed -i .sed 's/weight: /weight: 103/' content/utilities/_index.md
# rm content/{modules,workflows,utilities}/_index.md.sed
