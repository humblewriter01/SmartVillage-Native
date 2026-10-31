#!/usr/bin/env python3
"""Dart source checks that do not need the Dart SDK.

Two classes of hard compile error are invisible to the bracket-balance check in
`check_dart.py`, because that check strips string literals before looking:

1. **A string that terminates early.** Hausa is full of apostrophes —
   `sa'o'i`, `ma'aikaci`, `ƙarfe'` — and in a single-quoted Dart literal the
   first apostrophe ends the string. Writing `'... sa'o\\'i ...'` (one quote
   escaped, the other not) produces `Expected ';' after this.` This is exactly
   what broke the first `flutter build apk`.
2. **Duplicate elements in a literal.** `const Set<String>{'kashi', ...,
   'kashi'}` is a compile error (`conflicts with another existing element`);
   the same applies to duplicate string keys in a map literal.

Both are detected here with a small hand-rolled lexer that understands
`${...}` interpolation, nested strings inside interpolation, raw strings and
both comment styles.
"""

from __future__ import annotations

from collections import Counter
from typing import List, Tuple

#: Escapes Dart accepts after a backslash inside a normal string literal.
VALID_ESCAPES = set("nrtbfv\\'\"$")


class StringScanner:
    """Walks a Dart source file and validates every string literal."""

    def __init__(self, text: str) -> None:
        self.text = text
        self.length = len(text)
        self.index = 0
        self.line = 1
        self.problems: List[Tuple[int, str]] = []

    # ------------------------------------------------------------------ utils
    def _skip_code_until_brace(self) -> None:
        """Consume Dart code inside `${ ... }` up to the matching brace."""
        depth = 1
        while self.index < self.length:
            char = self.text[self.index]
            if char == "\n":
                self.line += 1
                self.index += 1
                continue
            if self.text.startswith("//", self.index):
                end = self.text.find("\n", self.index)
                self.index = self.length if end < 0 else end
                continue
            if self.text.startswith("/*", self.index):
                end = self.text.find("*/", self.index + 2)
                self.index = self.length if end < 0 else end + 2
                continue
            if self.text.startswith("'''", self.index) or self.text.startswith('"""', self.index):
                quote = self.text[self.index:self.index + 3]
                end = self.text.find(quote, self.index + 3)
                end = self.length if end < 0 else end
                self.line += self.text.count("\n", self.index, end)
                self.index = end + 3
                continue
            if char in "'\"":
                self.index += 1
                self._string_body(char)
                continue
            if char == "{":
                depth += 1
            elif char == "}":
                depth -= 1
                if depth == 0:
                    self.index += 1
                    return
            self.index += 1

    def _check_after_string(self) -> None:
        """Flag `'text'o...` — a string that ended before its closing quote."""
        position = self.index
        while position < self.length and self.text[position] in " \t":
            position += 1
        if position >= self.length:
            return
        following = self.text[position]
        if not (following.isalpha() or following in "_'\""):
            return

        line_start = self.text.rfind("\n", 0, self.index) + 1
        before = self.text[line_start:self.index].strip()
        # `import 'dart:math' as math;` and friends are directives, not
        # expressions: the trailing word is expected.
        if before.startswith(("import ", "export ", "part ")):
            return
        if before in ("import", "export", "part"):
            return

        fragment = self.text[max(0, self.index - 55):position + 12]
        self.problems.append(
            (self.line,
             "string closes early, then continues: ..." + fragment.replace("\n", " "))
        )

    def _string_body(self, quote: str) -> None:
        while self.index < self.length:
            char = self.text[self.index]
            if char == "\n":
                self.problems.append((self.line, "unterminated string literal"))
                self.line += 1
                self.index += 1
                return
            if char == "\\":
                nxt = self.text[self.index + 1] if self.index + 1 < self.length else ""
                if nxt == "\n":
                    self.line += 1
                    self.index += 2
                    continue
                if nxt not in VALID_ESCAPES and nxt not in ("u", "x"):
                    self.problems.append(
                        (self.line, "invalid escape sequence \\%s in string" % nxt)
                    )
                self.index += 2
                continue
            if char == "$":
                nxt = self.text[self.index + 1] if self.index + 1 < self.length else ""
                if nxt == "{":
                    self.index += 2
                    self._skip_code_until_brace()
                    continue
                if nxt.isalpha() or nxt == "_":
                    self.index += 1
                    while self.index < self.length and (
                        self.text[self.index].isalnum() or self.text[self.index] == "_"
                    ):
                        self.index += 1
                    continue
                self.index += 1
                continue
            if char == quote:
                self.index += 1
                self._check_after_string()
                return
            self.index += 1
        self.problems.append((self.line, "unterminated string at end of file"))

    # ------------------------------------------------------------------- run
    def run(self) -> List[Tuple[int, str]]:
        text = self.text
        while self.index < self.length:
            char = text[self.index]
            if char == "\n":
                self.line += 1
                self.index += 1
                continue
            if text.startswith("//", self.index):
                end = text.find("\n", self.index)
                self.index = self.length if end < 0 else end
                continue
            if text.startswith("/*", self.index):
                end = text.find("*/", self.index + 2)
                end = self.length if end < 0 else end
                self.line += text.count("\n", self.index, end)
                self.index = end + 2
                continue
            if text.startswith("'''", self.index) or text.startswith('"""', self.index):
                quote = text[self.index:self.index + 3]
                end = text.find(quote, self.index + 3)
                if end < 0:
                    self.problems.append(
                        (self.line, "unterminated triple-quoted string")
                    )
                    return self.problems
                self.line += text.count("\n", self.index, end)
                self.index = end + 3
                continue
            if char in "rR" and self.index + 1 < self.length and text[self.index + 1] in "'\"":
                quote = text[self.index + 1]
                end = self.index + 2
                while end < self.length and text[end] not in (quote, "\n"):
                    end += 1
                self.index = end + 1
                continue
            if char in "'\"":
                self.index += 1
                self._string_body(char)
                continue
            self.index += 1
        return self.problems


def scan_string_literals(text: str) -> List[Tuple[int, str]]:
    """Return (line, message) for every malformed string literal."""
    return StringScanner(text).run()


# --------------------------------------------------------------------------
# Literal duplicates
# --------------------------------------------------------------------------

import re
from collections import Counter

_TOKEN_START = re.compile(r"<(?:String|Set<String|Map<String)\b")
_CONST_LOOKBEHIND = 160


def _matching_angle(text: str, start: int) -> int:
    """Index just past the `>` matching the `<` at *start* (-1 if none)."""
    depth = 0
    for offset in range(start, len(text)):
        char = text[offset]
        if char == "<":
            depth += 1
        elif char == ">":
            depth -= 1
            if depth == 0:
                return offset + 1
        elif char in "\n;={}":
            if char != "\n":
                return -1
    return -1


def _matching_brace(text: str, start: int) -> int:
    depth = 0
    for offset in range(start, len(text)):
        char = text[offset]
        if char == "{":
            depth += 1
        elif char == "}":
            depth -= 1
            if depth == 0:
                return offset
    return -1


def _top_level_strings(body: str) -> tuple[list[str], list[str]]:
    """Strings at nesting depth 0: (all values, map keys).

    Nested braces and brackets are skipped so that keys of an inner map are not
    mistaken for keys of the outer one.
    """
    values: list[str] = []
    keys: list[str] = []
    depth = 0
    index = 0
    length = len(body)
    while index < length:
        char = body[index]
        if body.startswith("//", index):
            end = body.find("\n", index)
            index = length if end < 0 else end
            continue
        if body.startswith("/*", index):
            end = body.find("*/", index + 2)
            index = length if end < 0 else end + 2
            continue
        if char in "{[(":
            depth += 1
            index += 1
            continue
        if char in "}])":
            depth -= 1
            index += 1
            continue
        if char in "'\"" and depth == 0:
            quote = char
            index += 1
            start = index
            while index < length and body[index] != quote:
                index += 2 if body[index] == "\\" else 1
            token = body[start:index]
            index += 1
            values.append(token)
            lookahead = index
            while lookahead < length and body[lookahead] in " \t\n":
                lookahead += 1
            if lookahead < length and body[lookahead] == ":":
                keys.append(token)
            continue
        index += 1
    return values, keys


def scan_literal_duplicates(text: str) -> list[tuple[int, str]]:
    """Duplicate elements in const `Set` literals / duplicate keys in const maps.

    Only *const* literals are reported: duplicate entries in a non-const
    collection literal are legal Dart (last one wins), so flagging those would
    be a false positive.
    """
    problems: list[tuple[int, str]] = []
    for match in _TOKEN_START.finditer(text):
        angle_start = match.start()
        angle_end = _matching_angle(text, angle_start)
        if angle_end < 0:
            continue
        brace = angle_end
        while brace < len(text) and text[brace] in " \t\n":
            brace += 1
        if brace >= len(text) or text[brace] != "{":
            continue

        before = text[max(0, angle_start - _CONST_LOOKBEHIND):angle_start]
        declaration = before.split(";")[-1]
        if not re.search(r"\bconst\b", declaration):
            continue

        close = _matching_brace(text, brace)
        if close < 0:
            continue

        body = text[brace + 1:close]
        is_map = "," in text[angle_start:angle_end - 1]
        values, keys = _top_level_strings(body)
        items = keys if is_map else values
        if not items:
            continue

        counts = Counter(items)
        duplicates = sorted(word for word, count in counts.items() if count > 1)
        if duplicates:
            line = text.count("\n", 0, angle_start) + 1
            label = "Map key" if is_map else "Set element"
            problems.append(
                (line,
                 f"const {label} repeated {len(duplicates)} time(s): "
                 f"{duplicates[:8]}"
                 + (" …" if len(duplicates) > 8 else ""))
            )
    return problems


# --------------------------------------------------------------------------
# Masking: comments and string literals blanked, offsets preserved
# --------------------------------------------------------------------------

def mask_non_code(text: str) -> str:
    """Return *text* with comments and string literals replaced by spaces.

    Offsets and newlines are preserved, so a match position in the masked text
    maps straight back to a line number in the original. Used to find identifier
    references without being fooled by prose in comments or doc strings.
    """
    out = list(text)
    length = len(text)
    index = 0
    while index < length:
        char = text[index]
        if text.startswith("//", index):
            end = text.find("\n", index)
            end = length if end < 0 else end
            for i in range(index, end):
                out[i] = " "
            index = end
            continue
        if text.startswith("/*", index):
            end = text.find("*/", index + 2)
            end = length if end < 0 else end + 2
            for i in range(index, end):
                if out[i] != "\n":
                    out[i] = " "
            index = end
            continue
        triple = text.startswith("'''", index) or text.startswith('"""', index)
        raw = (not triple and char in "rR" and index + 1 < length
               and text[index + 1] in "'\"")
        if triple or raw or char in "'\"":
            if triple:
                quote = text[index:index + 3]
                start = index
                end = text.find(quote, index + 3)
                end = length if end < 0 else end + 3
            else:
                quote = "'" if raw else char
                start = index
                end = index + (1 if not raw else 2)
                while end < length:
                    if text[end] == "\\":
                        end += 2
                        continue
                    if text[end] == quote or text[end] == "\n":
                        end += 1
                        break
                    end += 1
            for i in range(start, min(end, length)):
                if out[i] != "\n":
                    out[i] = " "
            index = end
            continue
        index += 1
    return "".join(out)
