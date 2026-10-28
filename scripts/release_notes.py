"""Render the matching changelog section as an appcast description."""

import argparse
from pathlib import Path
import re
import xml.etree.ElementTree as ET

import markdown


def release_section(changelog: str, version: str) -> str:
    sections = re.split(r"^## (.+)\s*$", changelog, flags=re.MULTILINE)
    entries = dict(zip(sections[1::2], sections[2::2]))
    section = entries.get(version, entries.get("Unreleased", "")).strip()
    if not section:
        raise ValueError(f"No release notes for {version} or Unreleased in changelog.")
    return section


def description(changelog: str, version: str) -> str:
    element = ET.Element("description")
    element.text = markdown.markdown(release_section(changelog, version))
    return ET.tostring(element, encoding="unicode")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("changelog", type=Path)
    parser.add_argument("version")
    parser.add_argument("output", type=Path)
    args = parser.parse_args()
    args.output.write_text(
        description(args.changelog.read_text(encoding="utf-8"), args.version) + "\n",
        encoding="utf-8",
    )


if __name__ == "__main__":
    main()
