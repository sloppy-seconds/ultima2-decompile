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
    use_map = "--map" in sys.argv
    addrs = []
    if use_map:
        for line in open(os.path.join(ROOT, "disasm", "function-map.tsv")):
            p = line.split("\t")
            if p[0] != "start":
                addrs.append(p[0])
    else:
        with open(ENTRIES) as f:
            for line in f:
                t = line.split("#")[0].strip()
                if t:
                    addrs.append(t.split()[0])
    out_dir = os.path.join(ROOT, "decompiled", "reko")
    if use_map:
        OUT_G = os.path.join(out_dir, "ultimaii-map.dcproject")
    else:
        OUT_G = OUT
    od = out_dir if not use_map else os.path.join(out_dir + "-map")
    os.makedirs(od, exist_ok=True)
    out = [
        '<?xml version="1.0" encoding="utf-8"?>',
        '<project xmlns="http://schemata.jklnet.org/Reko/v5">',
        "  <arch>x86-real-16</arch>",
        "  <platform>ms-dos</platform>",
        "  <input>",
        f"    <location>{ROOT}/original/ultimaii.exe</location>",
        f"    <srcDir>{od}</srcDir>",
        f"    <asmDir>{od}</asmDir>",
        "    <user>",
    ]
    for a in addrs:
        out.append("      <procedure>")
        out.append(f"        <address>0800:{a}</address>")
        out.append("        <decompile>true</decompile>")
        out.append("      </procedure>")
    out += ["    </user>", "  </input>", "</project>", ""]
    with open(OUT_G, "w") as f:
        f.write("\n".join(out))
    print(f"wrote {OUT_G} with {len(addrs)} procedures")

if __name__ == "__main__":
    sys.exit(main())
