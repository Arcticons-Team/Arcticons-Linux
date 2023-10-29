#!/usr/bin/env bash

set -euo pipefail

SCRIPTPATH="$( cd -- "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"
cd $SCRIPTPATH

# Check if the icons folder of our parent repo exists, if not abort
if [ ! -e ../icons/white ]; then
	echo "Icon folder not found!"
	exit 1
fi

# Check if Inkscape is installed, if not abort
if ! type inkscape; then
	echo "Inkscape not found!"
	exit 1
fi

for style in black white; do
	if [ $style == "black" ]; then
		dest_root="./arcticons-light/scalable"
		symbolic_root="./arcticons-light/symbolic"
	else
		dest_root="./arcticons-dark/scalable"
		symbolic_root="./arcticons-dark/symbolic"
	fi
	for line in $(cat mapping.txt); do
		echo $line
		all_files_exist=true
		src=$(echo "$line" | cut -d, -f1)
		dests=( `echo "$line" | cut -d, -f2 | tr ':' ' '` )
		dest=${dests[0]}

		dests_paths=("${dests[@]/#/$dest_root/}")
		dests_paths=("${dests_paths[@]/%/.svg}")

		dests_paths_symbolic=("${dests[@]/#/$symbolic_root/}")
		dests_paths_symbolic=("${dests_paths[@]/%/-symbolic.svg}")
		dests_paths=("${dests_paths[@]}" "${dests_paths_symbolic[@]}")

		if [ ! -e "../icons/$style/$src.svg" ] && [ ! -e "./icons_linux/$style/$src.svg" ]; then
			echo "Skipping '$src', icon not found"
			continue
		fi

		if [ -e "$dest_root/$dest.svg" ]; then
			for file in "${dests_paths[@]}"; do
				if [ ! -e "$file" ]; then
					all_files_exist=false
					break
				fi
			done
			if [ all_files_exist ]; then
				continue
			fi
		fi

		mkdir -p "$dest_root/$(dirname "$dest")"

		if [ -e "../icons/$style/$src.svg" ]; then
			cp -v "../icons/$style/$src.svg" "$dest_root/$dest.svg"
		elif [ -e "./icons_linux/$style/$src.svg" ]; then
			cp -v "./icons_linux/$style/$src.svg" "$dest_root/$dest.svg"
		else
			echo "Skipping '$src', icon not found"
			continue
		fi

		grep -v 'stroke-width' "$dest_root/$dest.svg" > /dev/null && sed -i 's/\(stroke:[^;]\+\)/\1;stroke-width:1px/g' "$dest_root/$dest.svg"
		awk -i inplace -F 'stroke-width:|px' "{ print \$1 \"stroke-width:\" (\$2 * 2) \"px\" \$3; }" "$dest_root/$dest.svg"

		if [ ${#dests[@]} -gt 1 ]; then
			for i in $(seq 1 $((${#dests[@]}-1))); do
				mkdir -p "$dest_root/$(dirname "${dests[$i]}")"
				ln -vs "../${dests[0]}.svg" "$dest_root/${dests[$i]}.svg"
			done
		fi

		mkdir -p "$symbolic_root/$(dirname "$dest")"
		inkscape --actions="select-all;object-stroke-to-path" --export-filename="$symbolic_root/$dest-symbolic.svg" "$dest_root/$dest.svg" || true
		rm $dest_root/$dest*.0.svg || true

		if [ ${#dests[@]} -gt 1 ]; then
			for i in $(seq 1 $((${#dests[@]}-1))); do
				mkdir -p "$symbolic_root/$(dirname "${dests[$i]}")"
				ln -vs "../${dests[0]}-symbolic.svg" "$symbolic_root/${dests[$i]}-symbolic.svg"
			done
		fi
	done
done
