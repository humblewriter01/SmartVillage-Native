#!/usr/bin/env python3
"""Lightweight structural sanity check for the Dart sources.

The CI/real build uses `flutter analyze`; this script exists so the codebase can
be validated in environments where the Dart SDK is unavailable. It strips
comments and string literals, then verifies that brackets balance and that no
obvious template artefacts (e.g. unbalanced quotes) slipped in.
"""
from __future__ import annotations

import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
SRC = ROOT / "lib"

PAIRS = {")": "(", "]": "[", "}": "{"}


def strip_code(text: str) -> str:
    out = []
    i = 0
    n = len(text)
    while i < n:
        ch = text[i]
        # line comment
        if text.startswith("//", i):
            j = text.find("\n", i)
            i = n if j < 0 else j
            continue
        # block comment
        if text.startswith("/*", i):
            j = text.find("*/", i + 2)
            i = n if j < 0 else j + 2
            continue
        # raw string
        if ch in "rR" and i + 1 < n and text[i + 1] in "'\"":
            quote = text[i + 1]
            j = i + 2
            while j < n:
                if text[j] == quote:
                    break
                j += 1
            i = j + 1
            continue
        # multi-line string
        if text.startswith("'''", i) or text.startswith('"""', i):
            quote = text[i : i + 3]
            j = text.find(quote, i + 3)
            i = n if j < 0 else j + 3
            continue
        # single-line string with escapes / interpolation
        if ch in "'\"":
            quote = ch
            j = i + 1
            depth = 0
            while j < n:
                c = text[j]
                if c == "\\":
                    j += 2
                    continue
                if c == "$" and j + 1 < n and text[j + 1] == "{":
                    depth += 1
                    j += 2
                    continue
                if c == "}" and depth > 0:
                    depth -= 1
                    j += 1
                    continue
                if c == quote and depth == 0:
                    break
                j += 1
            i = j + 1
            continue
        out.append(ch)
        i += 1
    return "".join(out)


def check_brackets(name: str, code: str) -> list[str]:
    problems = []
    stack: list[tuple[str, int]] = []
    line = 1
    for ch in code:
        if ch == "\n":
            line += 1
        elif ch in "([{":
            stack.append((ch, line))
        elif ch in ")]}":
            if not stack:
                problems.append(f"{name}: unmatched '{ch}' at line {line}")
                return problems
            opener, opened_at = stack.pop()
            if opener != PAIRS[ch]:
                problems.append(
                    f"{name}: '{opener}' (line {opened_at}) closed by "
                    f"'{ch}' at line {line}"
                )
                return problems
    if stack:
        opener, opened_at = stack[-1]
        problems.append(f"{name}: unclosed '{opener}' opened at line {opened_at}")
    return problems


DECL_PATTERNS = (
    r"^(?:abstract |final |sealed |base )?(?:class|enum|typedef|mixin|extension)\s+(\w+)",
    r"^(?:const|final|var)\s+(?:[\w<>,\?\s]+?\s+)?(\w+)\s*=",
    r"^(?:void|String|int|double|bool|List<[^>]+>|Map<[^>]+>|Future<[^>]+>|"
    r"DateTime|Widget|Color)\s+(\w+)\s*\(",
)


def declared_names(files: list[pathlib.Path]) -> dict[pathlib.Path, set[str]]:
    """Top-level declarations per library, for the unused-import heuristic."""
    names: dict[pathlib.Path, set[str]] = {}
    for path in files:
        text = path.read_text(encoding="utf-8")
        found: set[str] = set()
        for pattern in DECL_PATTERNS:
            found.update(re.findall(pattern, text, re.M))
        names[path.resolve()] = found
    return names


def check_imports(files: list[pathlib.Path]) -> list[str]:
    """Report relative imports that resolve but export nothing used."""
    problems: list[str] = []
    names = declared_names(files)
    for path in files:
        text = path.read_text(encoding="utf-8")
        body = re.sub(r"^import '.*';$", "", text, flags=re.M).replace("library;", "")
        for match in re.finditer(r"^import '([^:']+)';", text, re.M):
            target = (path.parent / match.group(1)).resolve()
            exported = names.get(target, set())
            if not exported:
                continue
            if not any(re.search(r"\b" + re.escape(n) + r"\b", body) for n in exported):
                problems.append(
                    f"{path.relative_to(ROOT)}: unused import {match.group(1)}"
                )
    return problems


def main() -> int:
    problems: list[str] = []
    files = sorted(SRC.rglob("*.dart"))
    for path in files:
        text = path.read_text(encoding="utf-8")
        code = strip_code(text)
        problems.extend(check_brackets(str(path.relative_to(ROOT)), code))
    # basic import sanity: every relative import must resolve
    for path in files:
        for match in re.finditer(r"^import '([^:']+)';", path.read_text(encoding="utf-8"), re.M):
            target = (path.parent / match.group(1)).resolve()
            if not target.exists():
                problems.append(f"{path.relative_to(ROOT)}: missing import {match.group(1)}")

    problems.extend(check_imports(files))

    if problems:
        print("\n".join(problems))
        print(f"\n{len(problems)} problem(s) in {len(files)} files")
        return 1
    print(
        f"OK — {len(files)} Dart files, brackets balanced, "
        "imports resolve, no unused relative imports"
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
