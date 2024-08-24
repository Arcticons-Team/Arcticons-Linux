"""Validate the mapping file."""

from argparse import ArgumentParser
import logging
from pathlib import Path
import sys

import yaml

LOGGER = logging.getLogger()


def validate_mapping(*, fix: bool = False) -> bool:
    """Validate the mapping file."""
    valid = True

    with Path("mapping.yaml").open(encoding="utf8") as yaml_fp:
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
            logging.error("The following keys are duplicated: %s", keys_dupes)
            return False

    if sorted(yaml_doc.keys()) != list(yaml_doc.keys()):
        logging.error("Keys are not sorted!")
        if not fix:
            return False

    for entry, values in yaml_doc.items():
        values_seen = set()
        values_dupes = [x for x in values if x in values_seen or values_seen.add(x)]
        if len(values_dupes) > 0:
            logging.error(
                "The entry '%s' has these duplicate values: %s", entry, values_dupes
            )
            valid = False

        if sorted(values) != values:
            logging.error("The entry '%s' has unsorted values")
            valid = False

    if not fix:
        return valid

    fixed_doc = dict(sorted(yaml_doc.items()))
    for entry, values in yaml_doc.items():
        fixed_doc[entry] = sorted(set(values))

    with Path("mapping.yaml").open("w", encoding="utf8") as yaml_fp:
        yaml.safe_dump(fixed_doc, yaml_fp, default_flow_style=False)

    return True


if __name__ == "__main__":
    logging.basicConfig(level=logging.INFO)

    parser = ArgumentParser()
    parser.add_argument(
        "--fix", help="Fixes the mapping file.", action="store_true", default=False
    )
    args = parser.parse_args()

    if validate_mapping(fix=args.fix):
        sys.exit(0)
    else:
        sys.exit(1)
