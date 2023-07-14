#! /bin/env bash

cd docs || exit

# make modules documentation
find scamp/modules -name 'readme.yaml' |
	sed -e 's|^scamp/||' -e 's|/readme.yaml$||' |
	xargs -I @ sh -c "SCAMP_DOC=scamp/@/readme.yaml hugo new --kind doc-module --force @.md"

# make workflows documentation
find scamp/workflows -name 'readme.yaml' |
	sed -e 's|^scamp/||' -e 's|/readme.yaml$||' |
	xargs -I @ sh -c "SCAMP_DOC=scamp/@/readme.yaml hugo new --kind doc-workflow --force @/_index.md"

find scamp/utilities -name 'main.yaml' |
	sed -e 's|^scamp/||' -e 's|/main.yaml$||' |
	xargs -I @ sh -c "SCAMP_DOC=scamp/@/main.yaml hugo new --kind doc-utility --force @.md"

SCAMP_DOC=scamp/main.yaml hugo new --kind doc-user-parameters --force usage-guides/user-parameters/_index.md

# make directory listings where _index.md is not found
find content/{modules,workflows,utilities} -mindepth 0 -type d -not -exec test -e '{}/_index.md' ';' -print |
	xargs -I @ sh -c "hugo new --kind docs-group --force @/_index.md"

# set ordering for documentation
sed -i 's/weight: /weight: 101/' content/modules/_index.md
sed -i 's/weight: /weight: 102/' content/workflows/_index.md
sed -i 's/weight: /weight: 103/' content/utilities/_index.md

