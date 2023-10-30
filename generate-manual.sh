#!/usr/bin/env bash
#
# Generates the arcticons freedesktop icon theme.
#
# Usage: ./generate.sh [STYLE [LINE_WEIGHT]]
#
# STYLE:
#   Either "white" or "black"
#
# LINE_WEIGHT:
#   The relative thickness of the generated icon lines. Can be any positive
#   number (recommended range: about 0.75 to 1.5). A value of 1 means line
#   weight for the 48x48 is identical to the original line weight.
#
# This will create an `arcticons` directory in the current working dir
# containing the icon theme and an archive of the directory as
# `arcticons.tar.gz`.
#
# WARNING! If the directory already exists, its original contents will be wiped.
#
# The generated icons can be defined via the `mapping.txt` file. Each line
# represents a single icon and has the following format:
#
# <source_icon_name>,<destination_icon_path>
#
# ... where <source_icon_name> is the name of the icon in the original Arcticons
# for Android icon set and <destination_icon_path> is the path (name and,
# optionally, preceding directories) of the generated icon in the freedesktop
# icon theme.

set -euo pipefail

# parse the command line options
destination=./arcticons
archive=false
style=white
line_weight=1.0
while [[ $# -gt 0 ]]; do
	case $1 in
	-d | --destination)
		dest=$2
		shift
		shift
		;;
	-a | --archive)
		archive=true
		shift
		;;
	-s | --style)
		style=$2
		shift
		shift
		;;
	-l | --line-weight)
		line_weight=$2
		shift
		shift
		;;
	*)
		echo "Unexpected option $1"
		exit 1
		;;
	esac
done

# look for required programs
if ! type yq >/dev/null || ! type jq >/dev/null; then
	echo "error: yq and jq need to be installed for yaml parsing"
	exit 1
fi

inkscape=false
if type inkscape >/dev/null; then
	inkscape=true
else
	echo "Inkscape not found, not creating symbolic icons"
fi

rm -r "$destination" 2>/dev/null || true

# parse the yaml
mapfile -d '' kvpairs < <(yq -cM --raw-output0 'to_entries[]' mapping.yaml)
for kvpair in "${kvpairs[@]}"; do
	src=$(jq -r '.key' <<<"$kvpair")
	mapfile -d '' dests < <(jq --raw-output0 '.value[]' <<<"$kvpair")
	dest=${dests[0]}
	echo "$src: ${dests[*]}"

	dest_root="$destination/scalable"
	# copy the icons to the destination
	mkdir -p "$dest_root/$(dirname "$dest")"

	if [ -e "../icons/$style/$src.svg" ]; then
		cp -v "../icons/$style/$src.svg" "$dest_root/$dest.svg"
	elif [ -e "./icons_linux/$style/$src.svg" ]; then
		cp -v "./icons_linux/$style/$src.svg" "$dest_root/$dest.svg"
	else
		echo "Skipping '$src', icon not found"
		continue
	fi

	# apply the line weight replacement
	grep -v 'stroke-width' "$dest_root/$dest.svg" >/dev/null && sed -i 's/\(stroke:[^;]\+\)/\1;stroke-width:1px/g' "$dest_root/$dest.svg"
	awk -i inplace -F 'stroke-width:|px' "{ print \$1 \"stroke-width:\" (\$2 * $line_weight) \"px\" \$3; }" "$dest_root/$dest.svg"

	# create symbolic links for duplicate icons
	if [ ${#dests[@]} -gt 1 ]; then
		for i in $(seq 1 $((${#dests[@]} - 1))); do
			mkdir -p "$dest_root/$(dirname "${dests[$i]}")"
			ln -vs "../${dests[0]}.svg" "$dest_root/${dests[$i]}.svg"
		done
	fi

	# creating scalable
	if $inkscape; then
		dest_root="$destination/symbolic"
		src_root="$destination/scalable"

		mkdir -p "$dest_root/$(dirname "$dest")"
		inkscape --actions="select-all;object-stroke-to-path" --export-filename="$dest_root/$dest-symbolic.svg" "$src_root/$dest.svg" || true
		#rm $src_root/$dest*.0.svg || true

		if [ ${#dests[@]} -gt 1 ]; then
			for i in $(seq 1 $((${#dests[@]} - 1))); do
				mkdir -p "$dest_root/$(dirname "${dests[$i]}")"
				ln -vs "../${dests[0]}-symbolic.svg" "$dest_root/${dests[$i]}-symbolic.svg"
			done
		fi
	fi
done

folders=(8x8 16x16 16x16@2x 18x18 18x18@2x 22x22 22x22@2x 24x24 24x24@2x 32x32 32x32@2x 42x42 48x48 48x48@2x 64x64 64x64@2x 84x84 96x96 128x128)
for folder in "${folders[@]}"; do
	ln -sv scalable "arcticons/$folder"
done

cp index.theme arcticons/

if $archive; then
	tar czf arcticons.tar.gz arcticons
fi
