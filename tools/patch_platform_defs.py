#!/usr/bin/env python3
"""One-shot: switch portable asm from linux defs include to platform_defs.inc."""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OLD = '%include "src/hal/linux_x86_64/defs.inc"'
NEW = '%include "src/hal/platform_defs.inc"'

def main() -> None:
    for path in ROOT.rglob("*.asm"):
        if "src/hal/win_x86_64" in path.as_posix():
            continue
        text = path.read_text(encoding="utf-8")
        if OLD not in text:
            continue
        path.write_text(text.replace(OLD, NEW), encoding="utf-8")
        print(path.relative_to(ROOT))

if __name__ == "__main__":
    main()
