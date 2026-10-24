# sub_21d8 — the water-only arm, reached only for mon_type 0x2C and 0x48: DS:1F == 0x00
#           accepts, anything else refuses. A sea creature and a frigate therefore move on
#           water and nowhere else, which is the first place in this tree where those two
#           species are separated by behaviour rather than by art.
# func 21D8..21DE  len 0007 B  evidence: seed+reko
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_21d8:
L_0023d8:
        mov    0x1f,%al
L_0023db:
        cmp    $0x0,%al
L_0023dd:
        jne L_0023fc
