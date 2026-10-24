# sub_21bd — step gate, tile clause: 0x10 (art 0x04, the mountain; proven impassable for the
#           player too by a live walk, docs/passability-findings.md F11) is refused.
# func 21BD..21C4  len 0008 B  evidence: seed+reko
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_21bd:
L_0023bd:
        nop
L_0023be:
        mov    0x1f,%al
L_0023c1:
        cmp    $0x10,%al
L_0023c3:
        je L_0023fc
