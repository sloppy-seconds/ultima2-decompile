#!/usr/bin/env python3
"""CP5: build the Reko .dcproject seeding one procedure per entry in seed-entries.txt.

Format requirements (docs/reko-install.md): arch/platform are ELEMENTS; paths absolute;
procedures under <input><user>. Addresses use the Reko form 0800:XXXX.
"""
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ENTRIES = os.path.join(ROOT, "disasm", "seed-entries.txt")
OUT = os.path.join(ROOT, "decompiled", "reko", "ultimaii.dcproject")

def main():
    addrs = []
    with open(ENTRIES) as f:
        for line in f:
            t = line.split("#")[0].strip()
            if t:
                addrs.append(t.split()[0])
    out = [
        '<?xml version="1.0" encoding="utf-8"?>',
        '<project xmlns="http://schemata.jklnet.org/Reko/v5">',
        "  <arch>x86-real-16</arch>",
        "  <platform>ms-dos</platform>",
        "  <input>",
        f"    <location>{ROOT}/original/ultimaii.exe</location>",
        f"    <srcDir>{ROOT}/decompiled/reko</srcDir>",
        f"    <asmDir>{ROOT}/decompiled/reko</asmDir>",
        "    <user>",
    ]
    for a in addrs:
        out.append("      <procedure>")
        out.append(f"        <address>0800:{a}</address>")
        out.append("        <decompile>true</decompile>")
        out.append("      </procedure>")
    out += ["    </user>", "  </input>", "</project>", ""]
    with open(OUT, "w") as f:
        f.write("\n".join(out))
    print(f"wrote {OUT} with {len(addrs)} procedures")

if __name__ == "__main__":
    sys.exit(main())
