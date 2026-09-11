#!/usr/bin/env python3
"""Catch the trap that has now cost this project four separate bugs.

A `local function f` declared partway down a file resolves as a nil GLOBAL in
everything above it. Lua compiles that happily -- `luac -p` passes, the tests
pass, and the call blows up at runtime the first time it is reached. It has hit
the AddOn three times inside pcalls, where it failed silently, and once in the
probe, where it stopped `/unrecon` running at all.

This reports any call to a file-local function that appears before that
function is defined.
"""
import re, sys, pathlib

DEF = re.compile(r'^(\s*)local function ([A-Za-z_][A-Za-z0-9_]*)\s*\(', re.M)

def check(path):
    src = path.read_text()
    lines = src.split('\n')
    bad = []
    for m in DEF.finditer(src):
        indent, name = m.group(1), m.group(2)
        # Only file-level locals. A nested one is scoped to its enclosing
        # function and a call above it is a different question.
        if indent:
            continue
        def_line = src[:m.start()].count('\n') + 1
        call = re.compile(r'(?<![\w.:])' + re.escape(name) + r'\s*\(')
        for i, line in enumerate(lines[:def_line - 1], start=1):
            code = line.split('--', 1)[0]
            if call.search(code):
                bad.append((i, name, def_line))
    return bad

fail = 0
for arg in sys.argv[1:]:
    for path in sorted(pathlib.Path('.').glob(arg)):
        for line, name, def_line in check(path):
            print(f"  [FORWARD REF] {path}:{line} calls {name}(), "
                  f"defined at line {def_line}")
            fail += 1

if fail:
    print(f"{fail} forward reference(s) -- these are nil at runtime, not syntax errors.")
    sys.exit(1)
print("forward refs   ok")
