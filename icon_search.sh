#!/usr/bin/env bash

# This script searches for icons on your system by name to help find entries for mapping.yaml

# -n flag is used for the name of the app for which you are looking for icons
# -v flag enables verbose mode which displays more info

while getopts n:v flag
do
    case "${flag}" in
        n) appName=${OPTARG};;
        v) verbose=1
    esac
done

declare -a paths
readarray -t paths < <(find /usr/share/icons/ ~/.local/share/icons/ -type f -name "*${appName}*.*") # Make an array storing every result for the given appName
declare -A entries

for path in ${paths[@]};
do
    entry="$(basename "$(dirname "$path")")/$(basename "${path%.*}")" # Remove the leading directories and extension
    entries[$entry]+="\t$path\n"
done

if [ $verbose ]; then

    for entry in ${!entries[@]};
    do
        path=${entries["$entry"]}
        printf "$entry found at:\n$path" # Return entry and path of icon file
    done

else

    for entry in ${!entries[@]};
    do
        printf "$entry\n" # Return entry
    done
fi

# P. S. I hate writing bash scripts...
