import unittest
from pathlib import Path
import subprocess
import sys
import tempfile
import xml.etree.ElementTree as ET

from release_notes import description, release_section


class ReleaseNotesTests(unittest.TestCase):
    def test_cli_markdown_uses_selected_version(self):
        with tempfile.TemporaryDirectory() as directory:
            changelog = Path(directory) / "CHANGELOG.md"
            output = Path(directory) / "notes.md"
            changelog.write_text("## Unreleased\n\n- Future\n\n## 3.0\n\n- **Shipped** & tested\n", encoding="utf-8")
            subprocess.run(
                [sys.executable, str(Path(__file__).with_name("release_notes.py")),
                 str(changelog), "3.0", str(output), "--format", "markdown"],
                check=True,
            )
            self.assertEqual(output.read_text(encoding="utf-8"), "- **Shipped** & tested\n")

    def test_selects_exact_version_before_unreleased(self):
        changelog = "# Changelog\n\n## Unreleased\n\n- Future\n\n## 3.0.0-RC.3\n\n- Shipped\n\n## 3.0.0-RC.2\n\n- Older\n"
        self.assertEqual(release_section(changelog, "3.0.0-RC.3"), "- Shipped")

    def test_falls_back_to_unreleased_for_new_version(self):
        self.assertEqual(release_section("## Unreleased\n\n- New\n", "4.0"), "- New")

    def test_missing_or_empty_notes_fail(self):
        for changelog in ("# Changelog", "## Unreleased\n", "## 4.0\n\n## Unreleased\n- Future"):
            with self.subTest(changelog=changelog), self.assertRaises(ValueError):
                release_section(changelog, "4.0")

    def test_renders_html_and_xml_escaping(self):
        fragment = description("## Unreleased\n\n### Added\n\n- **Settings** & `SKU`\n- 2 < 5\n", "4.0")
        html = ET.fromstring(fragment).text
        self.assertIn("<h3>Added</h3>", html)
        self.assertIn("<li><strong>Settings</strong> &amp; <code>SKU</code></li>", html)
        self.assertIn("2 &lt; 5", html)


if __name__ == "__main__":
    unittest.main()
