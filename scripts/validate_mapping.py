#!/usr/bin/python3
"""Validate the mapping file."""

from argparse import ArgumentParser
import logging
from pathlib import Path
import sys

import yaml

LOGGER = logging.getLogger("validate_mapping")


def validate_mapping(file: Path, *, fix: bool = False) -> bool:
    """Validate the mapping file."""
    valid = True

    with file.open(encoding="utf8") as yaml_fp:
        yaml_doc: dict[str, list[str]] = yaml.safe_load(yaml_fp)

        yaml_fp.seek(0, 0)
        yaml_lines = yaml_fp.readlines()
        map_keys = [
            line.rstrip().removesuffix(":")
            for line in yaml_lines
            if line.rstrip().endswith(":")
        ]

        keys_seen = set()
        keys_dupes = [x for x in map_keys if x in keys_seen or keys_seen.add(x)]
        if len(keys_dupes) > 0:
            LOGGER.error("The following keys are duplicated: %s", keys_dupes)
            return False

    if sorted(yaml_doc.keys()) != list(yaml_doc.keys()):
        LOGGER.error("Keys are not sorted!")
        if not fix:
            return False

    for entry, values in yaml_doc.items():
        values_seen = set()
        values_dupes = [x for x in values if x in values_seen or values_seen.add(x)]
        if len(values_dupes) > 0:
            LOGGER.error(
                "The entry '%s' has these duplicate values: %s", entry, values_dupes
            )
            valid = False

        if sorted(values) != values:
            LOGGER.error("The entry '%s' has unsorted values", entry)
            valid = False

    # Check if a value is in multiple keys, with reporting the first key
    values_seen = {}
    for entry, values in yaml_doc.items():
        for value in values:
            if value in values_seen:
                LOGGER.error(
                    "The value '%s' is in multiple keys: %s and %s",
                    value,
                    values_seen[value],
                    entry,
                )
                valid = False
            else:
                values_seen[value] = entry

    if not fix:
        return valid

    fixed_doc = dict(sorted(yaml_doc.items()))
    for entry, values in yaml_doc.items():
        fixed_doc[entry] = sorted(set(values))

    with file.open("w", encoding="utf8") as yaml_fp:
        yaml.safe_dump(fixed_doc, yaml_fp, default_flow_style=False)

    return True


if __name__ == "__main__":
    logging.basicConfig(level=logging.INFO)

    parser = ArgumentParser()
    parser.add_argument(
        "--fix", help="Fixes the mapping file.", action="store_true", default=False
    )
    parser.add_argument(
        "--file", help="File to validate", type=Path, default=Path("mapping.yaml")
    )
    args = parser.parse_args()

    if validate_mapping(args.file, fix=args.fix):
        sys.exit(0)
    else:
        sys.exit(1)
