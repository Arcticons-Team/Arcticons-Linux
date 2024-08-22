"""Icon Search."""
# Example usage: python ./icon-search.py steam -v
import glob
import argparse

# Parse arguments from command line
parser = argparse.ArgumentParser()
parser.add_argument("appname", help="name of the app to search icons for")
parser.add_argument("-v", "--verbose", help="increase output verbosity",
                    action="store_true")
args = parser.parse_args()
# Search
paths = glob.glob("/usr/share/icons/**/**" + args.appname + "**",
                  recursive=True) + \
        glob.glob("/home/**/.local/share/icons/**/**" + args.appname + "**",
                  recursive=True)
entries = {}
# Processing
for path in paths:
    entry = (path.split("/")[-2] + "/"
             + path.split("/")[-1]).split(".")[0:-1][0]
    if entry in entries.keys():
        entries[entry].append(path)
    else:
        entries[entry] = [path]
# Display results
if args.verbose:
    for (entry, entry_paths) in entries.items():
        print(entry + " found in:")
        for entry_path in entry_paths:
            print("\t" + entry_path)
else:
    for entry in entries:
        print(entry)
