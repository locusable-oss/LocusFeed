#!/usr/bin/env bash
# Static MVP acceptance for LocusFeed. No Xcode, no signing, no git tag.
set -u
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
fail=0

ok() { printf 'ok   %s\n' "$1"; }
bad() { printf 'FAIL %s\n' "$1" >&2; fail=1; }

checklist="docs/checklist.md"
if [[ ! -f "$checklist" ]]; then
  bad "missing docs/checklist.md"
  exit 1
fi

if grep -q "GNU GENERAL PUBLIC LICENSE" LICENSE \
  && grep -q "Version 3" LICENSE \
  && grep -q "Locusable Studio" COPYRIGHT; then
  ok "GPL-3.0 LICENSE and COPYRIGHT"
else
  bad "LICENSE must be GPL-3.0 and COPYRIGHT must name Locusable Studio"
fi

while IFS= read -r path; do
  if [[ -f "$path" ]]; then
    ok "file $path"
  else
    bad "missing file $path"
  fi
done < <(grep -oE 'check:file:[A-Za-z0-9_./-]+' "$checklist" | sed 's/^check:file://' | sort -u)

while IFS= read -r spec; do
  file="${spec%%:*}"
  needle="${spec#*:}"
  if [[ -f "$file" ]] && grep -qF -- "$needle" "$file"; then
    ok "contains $file"
  else
    bad "missing '$needle' in $file"
  fi
done < <(grep -oE 'check:contains:[^ ]+' "$checklist" | sed 's/^check:contains://' | sort -u)

while IFS= read -r sym; do
  if grep -R -q -F --include='*.swift' -- "$sym" Sources LocusFeed Tests 2>/dev/null; then
    ok "symbol $sym"
  else
    bad "missing Swift symbol $sym"
  fi
done < <(grep -oE 'check:symbol:[A-Za-z0-9_]+' "$checklist" | sed 's/^check:symbol://' | sort -u)

if grep -q 'check:no-tag' "$checklist"; then
  # Project sources and the Makefile must not invoke git tag or gh release.
  # Docs may mention the prohibition; they are not scanned.
  if grep -R -n -E '(^|[;&|[:space:]])(git tag|gh release)([[:space:]]|$)' \
      Makefile Package.swift project.yml Sources LocusFeed Tests 2>/dev/null; then
    bad "tag or release command found in project files"
  else
    ok "no tag or release command"
  fi
  if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    if [[ -n "$(git tag --points-at HEAD)" ]]; then
      bad "HEAD is tagged; this checklist must not tag"
    else
      ok "HEAD is untagged"
    fi
  fi
fi

python3 - "$ROOT" << 'PY'
import sys
from pathlib import Path
root = Path(sys.argv[1])
errors = []
for path in list(root.joinpath("Sources").rglob("*.swift")) + list(root.joinpath("LocusFeed").rglob("*.swift")) + list(root.joinpath("Tests").rglob("*.swift")):
    text = path.read_text()
    out = []
    i = 0
    n = len(text)
    while i < n:
        if text.startswith("//", i):
            j = text.find("\n", i)
            i = n if j < 0 else j
            continue
        if text.startswith("/*", i):
            j = text.find("*/", i + 2)
            i = n if j < 0 else j + 2
            continue
        if text.startswith('"""', i):
            j = text.find('"""', i + 3)
            i = n if j < 0 else j + 3
            continue
        if text[i] == '"':
            i += 1
            while i < n:
                if text[i] == "\\":
                    i += 2
                    continue
                if text[i] == '"':
                    i += 1
                    break
                i += 1
            continue
        out.append(text[i])
        i += 1
    stack = []
    pairs = {")": "(", "]": "[", "}": "{"}
    for ch in out:
        if ch in "({[":
            stack.append(ch)
        elif ch in ")}]":
            if not stack or stack[-1] != pairs[ch]:
                errors.append(f"{path.relative_to(root)}: mismatched {ch}")
                break
            stack.pop()
    else:
        if stack:
            errors.append(f"{path.relative_to(root)}: unclosed {stack[-4:]}")
if errors:
    print("FAIL swift braces")
    for err in errors:
        print("FAIL", err)
    sys.exit(1)
print(f"ok   swift braces ({len(list(root.joinpath('Sources').rglob('*.swift')) + list(root.joinpath('LocusFeed').rglob('*.swift')))} files)")
PY
if [[ $? -ne 0 ]]; then
  fail=1
fi

if [[ $fail -ne 0 ]]; then
  printf 'self-check failed\n' >&2
  exit 1
fi
printf 'self-check passed (static, no Xcode, no tag)\n'
