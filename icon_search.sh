#!/bin/bash

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
readarray -t paths < <(find /usr/share/icons/ -name *$appName*.*) # Make an array storing every result for the given appName
declare -A entries

for path in ${paths[@]};
do
    entry=${path#*/*/*/*/*/*/} # Remove the first few directories
    entry=${entry%.*} # Remove file extension (must be seperate since bash disallows chaining parameter expansions)
    entries[$entry]=$path
done

if [ $verbose ]; then

    for entry in ${!entries[@]};
    do
        path=${entries["$entry"]}
        echo "$entry found at $path" # Return entry and path of icon file
    done

else

    for entry in ${!entries[@]};
    do
        echo $entry # Return entry
    done
fi

# P. S. I hate writing bash scripts...
