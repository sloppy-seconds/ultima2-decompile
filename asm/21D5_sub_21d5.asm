# sub_21d5 — step gate default: every tile from 0x14 up that is not 0x5C or 0x70 is refused,
#           which is 57 of the 64 reachable tile bytes. Includes 0x78 (art 0x1E, the solid
#           blocks that make up town buildings) and the whole 0x80..0xE4 letter range.
# func 21D5..21D7  len 0003 B  evidence: seed+reko
# calls: L_0023fc
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_21d5:
L_0023d5:
        jmp L_0023fc
L_0023d7:
        nop
