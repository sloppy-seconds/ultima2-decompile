# sub_21a6 — step gate, species clause 1: mon_type == 0x2C goes to asm/21D8, the water-only
#           arm. 0x2C >> 2 == art 0x0B, the sea creature in disasm/tile-art.tsv.
# func 21A6..21AD  len 0008 B  evidence: seed+reko
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_21a6:
L_0023a6:
        mov    0x197(%di),%al
L_0023aa:
        cmp    $0x2c,%al
L_0023ac:
        je L_0023d8
