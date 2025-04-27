#!/usr/bin/python3
"""Generate the icons for Arcticons."""

# ruff: noqa: PLR0912

from __future__ import annotations

from argparse import ArgumentParser
from configparser import ConfigParser
import contextlib
import logging
from os import symlink
from pathlib import Path
import re
from shutil import rmtree, which
import subprocess  # noqa: S404
import tomllib
from typing import TypedDict

from lxml import etree
from scour import scour
import yaml

LOGGER = logging.getLogger("generate_icons")

has_inkscape = bool(which("inkscape"))


class GeneratorEntry(TypedDict):
    """A config entry for generationg icons."""

    name: str
    comment: str
    inherits: str
    overwrite: bool
    archive: bool
    src_color: str
    color: str
    line_weight: int
    src_paths: list[str]


type MappingYaml = dict[str, list[str]]


def process_entry(
    entry: str, dests: list[str], destination: Path, config: GeneratorEntry
) -> None:
    """Process an entry."""
    scalable_root = destination / "scalable"
    symbolic_root = destination / "symbolic"

    LOGGER.info("%s: creating %s", entry, dests)

    if not any((not (scalable_root / (dest + ".svg")).exists()) for dest in dests):
        LOGGER.info("%s: Skipping, all icons already exist.", entry)
        return

    dest = dests[0]

    (scalable_root / dest).parent.mkdir(parents=True, exist_ok=True)

    src_file = None

    for src_dir in config["src_paths"]:
        src_path = Path(src_dir)
        if (src_path / f"{entry}.svg").exists():
            src_file = src_path / f"{entry}.svg"
            break
    if src_file is None:
        LOGGER.error("%s: Skipping, icon not found", entry)
        return

    LOGGER.info("%s: %s -> %s", entry, src_file, scalable_root / f"{dest}.svg")

    svg_file = etree.parse(src_file)
    svg_root = svg_file.getroot()

    circles = svg_root.findall(".//{http://www.w3.org/2000/svg}circle")
    for circle in circles:
        if circle.get("r") in {"0.75", ".75"}:
            circle.set("r", str(0.75 * config["line_weight"]))

    style_tag = svg_file.getroot().find(".//{http://www.w3.org/2000/svg}style")
    if style_tag is None or style_tag.text is None:
        LOGGER.error("%s: file %s doesn't have a style tag!", entry, src_file)
        return

    if "stroke-width" in style_tag.text:
        style_tag.text = re.sub(
            r"(stroke-width\s*:)[^;]+;",
            rf"\g<1>{config['line_weight']}px;",
            style_tag.text,
        )
    else:
        style_tag.text = re.sub(
            r"(stroke\s*:[^;]+;)",
            rf"\1stroke-width:{config['line_weight']}px;",
            style_tag.text,
        )

    style_tag.text = style_tag.text.replace(config["src_color"], config["color"])
    svg_file.write(
        scalable_root / f"{dest}.svg", xml_declaration=True, encoding="UTF-8"
    )

    if len(dests) > 1:
        for dest_file in dests[1:]:
            (scalable_root / f"{dest_file}.svg").parent.mkdir(
                parents=True,
                exist_ok=True,
            )
            (scalable_root / f"{dest_file}.svg").unlink(missing_ok=True)

            LOGGER.info(
                "%s: symlink: %s -> %s",
                entry,
                scalable_root / f"{dest_file}.svg",
                (scalable_root / f"{dest}.svg").relative_to(
                    (scalable_root / f"{dest_file}.svg").parent,
                    walk_up=True,
                ),
            )

            symlink(
                (scalable_root / f"{dest}.svg").relative_to(
                    (scalable_root / f"{dest_file}.svg").parent,
                    walk_up=True,
                ),
                scalable_root / f"{dest_file}.svg",
            )

    if not has_inkscape:
        return

    (symbolic_root / dest).parent.mkdir(exist_ok=True, parents=True)

    LOGGER.info("%s: %s -> %s", entry, src_file, symbolic_root / f"{dest}-symbolic.svg")
    _ = subprocess.run(  # noqa: S603
        [  # noqa: S607
            "inkscape",
            "--actions=select-all;object-stroke-to-path",
            f"--export-filename={symbolic_root / dest}-symbolic.svg",
            "--export-overwrite",
            scalable_root / f"{dest}.svg",
        ],
        check=False,
    )
    with (symbolic_root / f"{dest}-symbolic.svg").open("r+") as symbolic_file:
        svg_data = scour.scourString(symbolic_file.read())
        symbolic_file.seek(0)
        symbolic_file.truncate()
        symbolic_file.write(svg_data)

    # remove .0.svg files in case of inkscape crashing
    for file in scalable_root.glob(f"{dest}*.0.svg"):
        file.unlink()

    if len(dests) > 1:
        for dest_file in dests[1:]:
            (symbolic_root / f"{dest_file}-symbolic.svg").parent.mkdir(
                parents=True,
                exist_ok=True,
            )
            (symbolic_root / f"{dest_file}-symbolic.svg").unlink(missing_ok=True)

            LOGGER.info(
                "%s: symlink: %s -> %s",
                entry,
                symbolic_root / f"{dest_file}-symbolic.svg",
                (symbolic_root / f"{dest}-symbolic.svg").relative_to(
                    (symbolic_root / f"{dest_file}-symbolic.svg").parent,
                    walk_up=True,
                ),
            )

            symlink(
                (symbolic_root / f"{dest}-symbolic.svg").relative_to(
                    (symbolic_root / f"{dest_file}-symbolic.svg").parent,
                    walk_up=True,
                ),
                symbolic_root / f"{dest_file}-symbolic.svg",
            )


def generate_destination(
    destination: Path, config: GeneratorEntry, mapping_yaml: MappingYaml
) -> None:
    """Generate the icons in the destination."""
    for entry, dests in mapping_yaml.items():
        process_entry(entry, dests, destination, config)


def generate_index_theme(destination: Path, config: GeneratorEntry) -> None:
    """Generate the target index.theme file."""

    index_theme_file = ConfigParser()
    index_theme_file.optionxform = lambda optionstr: optionstr
    _ = index_theme_file.read("index.theme")
    index_theme_file["Icon Theme"]["Name"] = config["name"]
    index_theme_file["Icon Theme"]["Comment"] = config["comment"]
    index_theme_file["Icon Theme"]["Inherits"] = config["inherits"]
    with (destination / "index.theme").open("w", encoding="utf8") as dest_fp:
        index_theme_file.write(dest_fp, space_around_delimiters=False)


def main(config_file: Path) -> None:
    """Generate all icons."""
    if not has_inkscape:
        LOGGER.warning("Inkscape was not detected, not creating symbolic icons.")

    config: dict[str, GeneratorEntry] = tomllib.loads(
        config_file.read_text(encoding="utf8")
    )

    with Path("mapping.yaml").open(encoding="utf8") as yaml_fp:
        mapping_yaml: MappingYaml = yaml.safe_load(yaml_fp)

    for section, entry in config.items():
        if entry["overwrite"]:
            rmtree(section)
        elif Path(section).exists():
            LOGGER.info('Destination "%s" exists, trying to update.', section)

        generate_destination(Path(section), entry, mapping_yaml)

        generate_index_theme(Path(section), entry)

        # link all the sizes to scalable
        for folder in (
            "8x8",
            "16x16",
            "16x16@2x",
            "18x18",
            "18x18@2x",
            "22x22",
            "22x22@2x",
            "24x24",
            "24x24@2x",
            "32x32",
            "32x32@2x",
            "42x42",
            "48x48",
            "48x48@2x",
            "64x64",
            "64x64@2x",
            "84x84",
            "96x96",
            "128x128",
        ):
            with contextlib.suppress(FileExistsError):
                symlink("scalable", Path(section) / folder, target_is_directory=True)


if __name__ == "__main__":
    parser = ArgumentParser()
    _ = parser.add_argument(
        "-c", "--config-file", help="The config file to read.", type=Path
    )
    args = parser.parse_args()

    logging.basicConfig(level=logging.INFO)

    main(args.config_file)
