#!/usr/bin/env bash
#
# Generates the arcticons freedesktop icon theme.
#
# Usage: see ./generate.sh --help
#
# The generated icons can be defined via the `mapping.yaml` file e.g.:
# '''
# bluetooth:
#    - apps/bluetooth
#    - devices/bluetooth
# '''
# will result in the icon 'bluetooth.svg' being copied to 'apps/bluetooth.svg'
# and 'devices/bluetooth.svg' being a relative symlink to 'apps/bluetooth.svg'

set -euo pipefail

# bold
b=$'\033[1m'
# color (for commands (blue))
c=$'\033[34m'
# reset
r=$'\033[0m'

function help {

	cat <<EOF
${b}USAGE$r:
    $c$0 [OPTIONS]$r

${b}OPTIONS$r:
    $c-h$r, $c--help$r
        shows this help

    $c-d$r, $c--destination$r <destination folder>
        The generated icon pack will be written to <destination folder>.
        If $c--remove$r is specified, an existing destination folder will be deleted.
        The default is "arcticons".

    $c-r$r, $c--remove$r
        The destination folder will be overwritten without asking.

    $c-a$r, $c--archive$r
        Compress the resulting icon pack into an $c<destination folder>.tar.gz$r.
        If $c--remove$r is specified, any existing file or folder with this name will be deleted.
    
    $c-s$r, $c--style$r
        Color of the resulting icons. Either 'black' or 'white'.

    $c-l$r, $c--line-weight$r
        The relative thickness of the generated icon lines. Can be any positive
        number (recommended range: about 0.75 to 1.5). A value of 1 means line
        weight for the 48x48 is identical to the original line weight.
EOF
}

# go to the path of the script
SCRIPTPATH="$(
	cd -- "$(dirname "$0")" >/dev/null 2>&1
	pwd -P
)"
cd "$SCRIPTPATH"

# look for required programs
if ! type yq >/dev/null || ! type jq >/dev/null; then
	echo "error: yq and jq need to be installed for yaml parsing"
	exit 1
fi

inkscape=false
if type inkscape && type scour; then
	inkscape=true
else
	echo "Inkscape not found, not creating symbolic icons"
fi

# check the mapping.yaml file to be in the right format
# - no whitespace in icon names
# - root is object
# - every value in the root object is list of strings
yq -rf validate_mapping.jq mapping.yaml || exit 1

# parse the command line options
destination=./arcticons
archive=false
style=white
line_weight=1.0
remove=false
while [[ $# -gt 0 ]]; do
	case $1 in
	-h | --help)
		help
		exit 0
		;;
	-r | --remove)
		remove=true
		;;
	-d | --destination)
		destination=$2
		shift
		;;
	-a | --archive)
		archive=true
		;;
	-s | --style)
		style=$2
		if [ "$style" != black ] && [ "$style" != white ]; then
			echo "error: style has to be either 'black' or 'white'"
			exit 1
		fi
		shift
		;;
	-l | --line-weight)
		line_weight=$2
		shift
		;;
	*)
		echo "Unexpected option $1"
		exit 1
		;;
	esac
	shift
done

if $remove; then
	rm -rf "$destination"
elif [ -e "$destination" ]; then
	echo "Not deleting existing destination '$destination'. Trying to update it instead."
fi

# parse the yaml
mapfile -d '' kvpairs < <(yq -cM --raw-output0 'to_entries[]' mapping.yaml)
for kvpair in "${kvpairs[@]}"; do
	src=$(jq -r '.key' <<<"$kvpair")
	mapfile -d '' dests < <(jq --raw-output0 '.value[]' <<<"$kvpair")
	dest=${dests[0]}
	printf '\n%s\n' "$c$src$r: ${dests[*]}"

	scalable_root="$destination/scalable"
	symbolic_root="$destination/symbolic"

	# skip if all destination files already exist (only possible without --remove)
	skip=true
	if [ ! -f "$scalable_root/$dest.svg" ]; then
		skip=false
	elif [ ${#dests[@]} -gt 1 ]; then
		for i in $(seq 1 $((${#dests[@]} - 1))); do
			if [ ! -L "$scalable_root/${dests[$i]}.svg" ]; then
				skip=false
				break
			fi
		done
	fi
	if $skip; then
		echo "Skipping $src, all icons already exist."
		continue
	fi

	# create destination directories
	mkdir -p "$scalable_root/$(dirname "$dest")"

	# check whether the src icon is in ./icons_linux or ../icons
	if [ -e "./icons_linux/$style/$src.svg" ]; then
		src_root="./icons_linux"
	elif [ -e "../icons/$style/$src.svg" ]; then
		src_root="../icons"
	else
		echo "Skipping '$src', icon not found"
		continue
	fi

	# copy the icons to the destination and apply the line weight replacement
	echo "$src_root/$style/$src.svg -> $scalable_root/$dest.svg"
	if [ -n "${src_root:-}" ]; then
		xmlstarlet ed -N x="http://www.w3.org/2000/svg" -u '//x:circle[@r = 0.75]/@r' -v "$(echo "0.75*$line_weight" | bc)px" \
			"$src_root/$style/$src.svg" >"$scalable_root/$dest.svg"
		sed -i 's/\(stroke:[^;]\+\)/\1;stroke-width:1px/g' "$scalable_root/$dest.svg"
		# awk -i inplace -F 'stroke-width:|px' "{ print \$1 \"stroke-width:\" (\$2 * $line_weight) \"px\" \$3; }" "$scalable_root/$dest.svg"
		sed -i "s/stroke-width:1/stroke-width:$line_weight/g" "$scalable_root/$dest.svg"
	fi

	# create symbolic links for duplicate icons
	if [ ${#dests[@]} -gt 1 ]; then
		for i in $(seq 1 $((${#dests[@]} - 1))); do
			mkdir -p "$scalable_root/$(dirname "${dests[$i]}")"
			rm -f "$scalable_root/${dests[$i]}.svg"
			ln -vsr "$scalable_root/$dest.svg" "$scalable_root/${dests[$i]}.svg"
		done
	fi

	# create symbolic icons
	if $inkscape; then
		mkdir -p "$symbolic_root/$(dirname "$dest")"
		echo "creating symbolic icon '$symbolic_root/$dest-symbolic.svg'"
		inkscape \
			--actions="select-all;object-stroke-to-path" \
			--export-filename="$symbolic_root/$dest-symbolic.svg" \
			--export-overwrite \
			"$scalable_root/$dest.svg" || true
		# shellcheck disable=SC2015
		scour --quiet "$symbolic_root/$dest-symbolic.svg" "$symbolic_root/$dest-symbolic.tmp.svg" &&
			rm "$symbolic_root/$dest-symbolic.svg" &&
			mv "$symbolic_root/$dest-symbolic.tmp.svg" "$symbolic_root/$dest-symbolic.svg" || true

		# remove .0.svg files in case of inkscape crashing
		rm -f "$scalable_root/$dest*.0.svg"

		if [ ${#dests[@]} -gt 1 ]; then
			for i in $(seq 1 $((${#dests[@]} - 1))); do
				mkdir -p "$symbolic_root/$(dirname "${dests[$i]}")"
				rm -f "$symbolic_root/${dests[$i]}-symbolic.svg"
				ln -vs "../${dests[0]}-symbolic.svg" "$symbolic_root/${dests[$i]}-symbolic.svg"
			done
		fi
	fi
done

# link all the sizes to scalable
folders=(8x8 16x16 16x16@2x 18x18 18x18@2x 22x22 22x22@2x 24x24 24x24@2x 32x32 32x32@2x 42x42 48x48 48x48@2x 64x64 64x64@2x 84x84 96x96 128x128)
for folder in "${folders[@]}"; do
	ln -svfT scalable "$destination/$folder"
done

# copy the index.theme
cp index.theme "$destination/"

# possibly create the archive
if $archive; then
	archivedest="$destination.tar.gz"
	if $remove; then
		rm -f "$archivedest"
	elif [ -e "$archivedest" ]; then
		read -rp "archive destination '$archivedest' already exists, delete? [y/n] " -n 1 choice
		echo # \n
		if [ "$choice" == y ]; then
			rm -f "$archivedest"
		else
			echo "Not deleting existing archive '$archivedest'!"
			exit 0
		fi
	fi
	tar czf "$archivedest" "$destination"
fi
