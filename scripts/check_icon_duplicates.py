#!/usr/bin/python3
"""Synchronize icons between black and white."""

from argparse import ArgumentParser
from filecmp import cmp
import logging
from pathlib import Path
import sys

LOGGER = logging.getLogger("check_icon_duplicates")


def main(src_folder: Path, target_folder: Path, *, fix: bool = False) -> bool:
    """Check if icons are in both black and white folders."""

    src_files = {a.relative_to(src_folder) for a in src_folder.glob("**/*.svg")}
    target_files = {
        a.relative_to(target_folder) for a in target_folder.glob("**/*.svg")
    }

    duplicates = src_files.intersection(target_files)
    if not duplicates:
        LOGGER.info("No duplicates found.")
        return True

    print("Following potential duplicate icons were found:")
    for file in sorted(duplicates):
        src_file = src_folder / file
        target_file = target_folder / file
        same_size = src_file.stat().st_size == target_file.stat().st_size
        same_content = False
        if same_size:
            same_content = cmp(src_file, target_file, shallow=False)

        if not same_size:
            print(
                f"{src_file} -> {target_file}; size different ({src_file.stat().st_size} -> {target_file.stat().st_size})"
            )
        else:
            print(
                f"{src_file} -> {target_file}; size same; content {'same' if same_content else 'different'}"
            )
        if fix and same_content:
            target_file.unlink()
    return False


if __name__ == "__main__":
    logging.basicConfig(level=logging.INFO)

    parser = ArgumentParser()
    parser.add_argument(
        "--fix",
        help="Removes the target file if the content between src and target file is the same.",
        action="store_true",
        default=False,
    )
    parser.add_argument(
        "--src-folder",
        help="Folder which contains the source icons",
        type=Path,
        required=True,
    )
    parser.add_argument(
        "--target-folder",
        help="The folder in which the icons are checked if there are duplicates of in the src folder",
        type=Path,
        required=True,
    )
    args = parser.parse_args()

    if not main(args.src_folder, args.target_folder, fix=args.fix):
        sys.exit(1)
