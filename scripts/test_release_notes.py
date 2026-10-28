import unittest
import xml.etree.ElementTree as ET

from release_notes import description, release_section


class ReleaseNotesTests(unittest.TestCase):
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
