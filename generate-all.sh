#!/usr/bin/env bash

# USAGE:
# ./generate-all.sh [--regenerate]
# When --regenerate is specified the folders arcticons-dark and arcticons-light
# will be deleted and completely regenerated.

set -euo pipefail

# go to the path of the script
cd -P -- "$(dirname "$0")"

# Check if the icons folder of our parent repo exists, if not abort
if [ ! -e ../icons/white ]; then
	echo "Icon folder not found!"
	exit 1
fi

# Check if Inkscape and Scour are installed, if not abort
if ! type inkscape || ! type scour; then
	echo "Inkscape not found!"
	exit 1
fi

if ! type xmlstarlet; then
	echo "xmlstarlet not found!"
	exit 1
fi

# Check if ./generate-manual.sh exists, if not abort
if [ ! -e ./generate-manual.sh ]; then
	echo "Script ./generate-manual.sh not found!"
	exit 1
fi

# Check if yq and jq are installed, if not abort
if ! type yq >/dev/null || ! type jq >/dev/null; then
	echo "error: yq and jq need to be installed for yaml parsing"
	exit 1
fi

# sort the mapping.yaml file with yq
if [[ $(yq --version) == *"(https://github.com/mikefarah/yq/)"* ]]; then
	yq -i -P '.[] |= sort' mapping.yaml
	yq -i -P 'sort_keys(..)' mapping.yaml
else
	yq -Syi '.[] |= sort' mapping.yaml
fi

# parse command line arguments
regenerate=false
while [[ $# -gt 0 ]]; do
	case $1 in
	--regenerate)
		regenerate=true
		;;
	*)
		echo "Unexpected option $1"
		exit 1
		;;
	esac
	shift
done

for style in black white; do
	if [ $style == "black" ]; then
		variant="Light"
	else
		variant="Dark"
	fi
	options=(--style "$style" --line-weight 2 --destination "./arcticons-${variant,,}")
	if $regenerate; then
		options+=(--remove)
	fi
	./generate-manual.sh "${options[@]}"

	# fix up the index.theme files
	index="./arcticons-${variant,,}/index.theme"
	sed -i "s/Name=Arcticons/Name=Arcticons $variant/g" "$index"
	sed -i "s/Comment=A Line-based icon pack\\./Comment=A Line-based icon pack. (Version for ${variant,,} themes)/g" "$index"
	if [ $variant == "Dark" ]; then
		sed -i 's/breeze/breeze-dark/g' "$index"
	fi
done
