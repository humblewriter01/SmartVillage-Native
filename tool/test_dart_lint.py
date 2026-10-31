#!/usr/bin/env python3
"""Self-tests for `tool/dart_lint.py`.

Run with:  python3 tool/test_dart_lint.py

`check_dart.py` already passed on the tree that failed to compile, so the checks
themselves need tests — otherwise a future edit could silently stop detecting
the very bug classes they were written for.
"""

import pathlib
import sys
import unittest

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))

from dart_lint import scan_literal_duplicates, scan_string_literals  # noqa: E402


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


class RepositoryTests(unittest.TestCase):
    """The real tree must stay clean — this is the check CI relies on."""

    def test_tts_chunker_lexicon_has_no_duplicates(self):
        root = pathlib.Path(__file__).resolve().parent.parent
        source = (root / "lib/services/tts/tts_chunker.dart").read_text(
            encoding="utf-8"
        )
        self.assertEqual(scan_literal_duplicates(source), [])
        self.assertEqual(scan_string_literals(source), [])

    def test_soil_service_strings_are_well_formed(self):
        root = pathlib.Path(__file__).resolve().parent.parent
        source = (root / "lib/services/soil_service.dart").read_text(
            encoding="utf-8"
        )
        self.assertEqual(scan_string_literals(source), [])


if __name__ == "__main__":
    unittest.main(verbosity=2)
