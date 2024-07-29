#!/bin/bash

# This script searches for icons on your system by name to help find entries for mapping.yaml

echo -n "Please enter an app to search for: "
read app # Store the prompted app name
declare -a paths
readarray -t paths < <(find /usr/share/icons/ -name *$app*.*) # Make an array storing every result for the given app name
for (( i=0; i<${#paths[@]}; i++ )); # For loop iterating over each result
do
    subpath=${paths[$i]#*/*/*/*/*/*/} # parameter expansion, remove shortest match of that many "/"'s to remove the first few directories
    echo "${subpath%.*}" # Return without the file extension
done

# P. S. I hate bash scripts...
