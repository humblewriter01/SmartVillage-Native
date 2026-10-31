#!/usr/bin/env python3
"""Self-tests for `tool/dart_lint.py`.

Run with:  python3 tool/test_dart_lint.py

`check_dart.py` already passed on the tree that failed to compile, so the checks
themselves need tests — otherwise a future edit could silently stop detecting
the very bug classes they were written for.
"""

import pathlib
import sys
import tempfile
import unittest

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))

from check_dart import check_icons  # noqa: E402
from dart_lint import (  # noqa: E402
    mask_non_code,
    scan_literal_duplicates,
    scan_string_literals,
)


class StringLiteralTests(unittest.TestCase):
    def test_hausa_apostrophes_in_single_quotes_are_flagged(self):
        # The exact shape of the bug that broke `flutter build apk`:
        # only the second apostrophe was escaped, so the first one closed
        # the literal and `sa` was left dangling as an identifier.
        source = "String f() => 'yi shirin a cikin sa'o\\'i 48 masu zuwa';\n"
        self.assertTrue(scan_string_literals(source))

    def test_hausa_apostrophes_in_double_quotes_are_fine(self):
        source = 'String f() => "yi shirin a cikin sa\'o\'i 48 masu zuwa";\n'
        self.assertEqual(scan_string_literals(source), [])

    def test_escaped_apostrophes_in_single_quotes_are_fine(self):
        source = "String f() => 'a cikin sa\\'o\\'i 48';\n"
        self.assertEqual(scan_string_literals(source), [])

    def test_interpolation_with_nested_string_is_fine(self):
        source = """String f(int x) => 'value ${x > 0 ? 'yes' : 'no'} done';\n"""
        self.assertEqual(scan_string_literals(source), [])

    def test_interpolation_with_apostrophe_in_nested_string_is_fine(self):
        source = """String f(String s) => 'got ${s == 'sa\\'o\\'i' ? 1 : 2}';\n"""
        self.assertEqual(scan_string_literals(source), [])

    def test_import_directive_is_not_an_early_close(self):
        source = "import 'dart:math' as math;\n"
        self.assertEqual(scan_string_literals(source), [])

    def test_unterminated_string_is_flagged(self):
        source = "String f() => 'never closed;\n"
        self.assertTrue(scan_string_literals(source))

    def test_triple_quoted_and_raw_strings_are_skipped(self):
        source = "String f() => '''it's fine'''; String g() => r'raw\\';\n"
        self.assertEqual(scan_string_literals(source), [])

    def test_comment_containing_quote_is_ignored(self):
        source = "// don't quote 'this\nString f() => 'ok';\n"
        self.assertEqual(scan_string_literals(source), [])


class LiteralDuplicateTests(unittest.TestCase):
    def test_duplicate_const_set_element_is_flagged(self):
        # Codemagic reports only the first offender; the checker must not care.
        source = (
            "class A {\n"
            "  static const Set<String> words = <String>{\n"
            "    'kashi', 'kashe', 'kashi',\n"
            "  };\n"
            "}\n"
        )
        problems = scan_literal_duplicates(source)
        self.assertEqual(len(problems), 1)
        self.assertIn("kashi", problems[0][1])

    def test_duplicate_const_map_key_is_flagged(self):
        source = "const m = <String, String>{'a': '1', 'a': '2'};\n"
        self.assertTrue(scan_literal_duplicates(source))

    def test_nested_map_keys_are_not_counted_as_outer_duplicates(self):
        # Both languages legitimately share the same inner keys.
        source = (
            "const t = <String, Map<String, String>>{\n"
            "  'en': <String, String>{'home': 'Home'},\n"
            "  'ha': <String, String>{'home': 'Gida'},\n"
            "};\n"
        )
        self.assertEqual(scan_literal_duplicates(source), [])

    def test_non_const_literal_duplicates_are_allowed(self):
        # Legal Dart (last value wins), so reporting it would be a false alarm.
        source = "final s = <String>{'a', 'a'};\n"
        self.assertEqual(scan_literal_duplicates(source), [])

    def test_unique_const_set_is_clean(self):
        source = "const s = <String>{'a', 'b', 'c'};\n"
        self.assertEqual(scan_literal_duplicates(source), [])


class IconCheckTests(unittest.TestCase):
    """`Icons.boil` failed only at `flutter build apk`; catch it locally."""

    def _check(self, source: str):
        with tempfile.TemporaryDirectory() as directory:
            path = pathlib.Path(directory) / "sample.dart"
            path.write_text(source, encoding="utf-8")
            return check_icons([path])

    def test_unknown_icon_is_flagged(self):
        problems = self._check("Widget f() => Icon(Icons.boil);\n")
        self.assertEqual(len(problems), 1)
        self.assertIn("Icons.boil does not exist", problems[0])

    def test_real_icons_pass(self):
        source = "Widget f() => Icon(Icons.check);\nIcon g() => Icon(Icons.water_drop);\n"
        self.assertEqual(self._check(source), [])

    def test_icon_named_in_a_comment_is_ignored(self):
        source = "// there is no Icons.boil any more\nIcon f() => Icon(Icons.water_drop);\n"
        self.assertEqual(self._check(source), [])

    def test_icon_named_in_a_string_is_ignored(self):
        source = "String f() => 'Icons.boil is not real';\n"
        self.assertEqual(self._check(source), [])


class MaskTests(unittest.TestCase):
    def test_mask_preserves_line_numbers(self):
        source = "// comment\nfinal s = 'text';\nfinal t = 1;\n"
        masked = mask_non_code(source)
        self.assertEqual(source.count("\n"), masked.count("\n"))
        self.assertEqual(len(source), len(masked))

    def test_mask_blanks_string_contents(self):
        self.assertNotIn("text", mask_non_code("final s = 'text';\n"))

    def test_mask_keeps_code(self):
        self.assertIn("Icons.check", mask_non_code("Icon(Icons.check),\n"))


class RepositoryTests(unittest.TestCase):
    """The real tree must stay clean — this is the check CI relies on."""

    def test_tts_chunker_lexicon_has_no_duplicates(self):
        root = pathlib.Path(__file__).resolve().parent.parent
        source = (root / "lib/services/tts/tts_chunker.dart").read_text(
            encoding="utf-8"
        )
        self.assertEqual(scan_literal_duplicates(source), [])
        self.assertEqual(scan_string_literals(source), [])

    def test_every_icon_reference_exists(self):
        root = pathlib.Path(__file__).resolve().parent.parent
        files = sorted((root / "lib").rglob("*.dart"))
        self.assertEqual(check_icons(files), [])

    def test_soil_service_strings_are_well_formed(self):
        root = pathlib.Path(__file__).resolve().parent.parent
        source = (root / "lib/services/soil_service.dart").read_text(
            encoding="utf-8"
        )
        self.assertEqual(scan_string_literals(source), [])


if __name__ == "__main__":
    unittest.main(verbosity=2)
