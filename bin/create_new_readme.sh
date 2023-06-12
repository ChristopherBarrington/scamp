#! /bin/env bash

# use hugo to create a template readme yaml file in a module
# bash bin/create_new_readme.sh modules/R/Seurat/make_assay

TARGET=${1:-null}

if [[ ${TARGET} == "null" ]]; then
	echo "no path specified!"
	exit
fi

(cd docs
hugo new --kind module-readme \
         --contentDir scamp \
         ${TARGET}/readme.md \
&& rename --remove-extension --append .yaml scamp/$_
)
