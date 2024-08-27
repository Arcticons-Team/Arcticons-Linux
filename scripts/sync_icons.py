#!/usr/bin/python3
"""Synchronize icons between black and white."""

from argparse import ArgumentParser
import logging
from pathlib import Path
import sys
from typing import Literal


def copy_file(src: Path, dest: Path, src_style: Literal["black", "white"]) -> None:
    """Copy a file and adjust the colors."""

    match src_style:
        case "black":
            replace_str = {("#000", "#fff"), ("#000000", "#ffffff")}
        case "white":
            replace_str = {
                ("#fff", "#000"),
                ("#ffffff", "#000000"),
                ("#FFF", "#000"),
                ("#FFFFFF", "#000000"),
            }
    with src.open("r") as src_fd, dest.open("w") as dest_fd:
        src_text = src_fd.read()
        for pattern in replace_str:
            src_text = src_text.replace(pattern[0], pattern[1])
        dest_fd.write(src_text)


def main(folder: Path, *, fix: bool = False) -> bool:
    """Check if icons are in both black and white folders."""

    valid = True
    if not (folder / "white").is_dir():
        logging.error("The 'white' folder could not be found!")
        return False
    if not (folder / "black").is_dir():
        logging.error("The 'black' folder could not be found!")
        return False

    files_black = {a.name for a in (folder / "black").glob("*.svg")}
    files_white = {a.name for a in (folder / "white").glob("*.svg")}

    black_not_white = files_black - files_white
    white_not_black = files_white - files_black

    if white_not_black:
        logging.error(
            "The following files are only in the 'white' folder: %s", white_not_black
        )
        valid = False
    if black_not_white:
        logging.error(
            "The following files are only in the 'black' folder: %s", black_not_white
        )
        valid = False

    if fix:
        for file in white_not_black:
            copy_file(folder / "white" / file, folder / "black" / file, "white")
        for file in black_not_white:
            copy_file(folder / "black" / file, folder / "white" / file, "black")

    return valid


if __name__ == "__main__":
    logging.basicConfig(level=logging.INFO)

    parser = ArgumentParser()
    parser.add_argument(
        "--fix", help="Fixes the mapping file.", action="store_true", default=False
    )
    parser.add_argument(
        "folder",
        help="Folder where the 'black' and 'white' folders are to check",
        type=Path,
    )
    args = parser.parse_args()

    if not main(args.folder, fix=args.fix):
        sys.exit(1)
