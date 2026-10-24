# sub_21cd — step gate, tile clause: everything below 0x14 that the three refuses above did
#           not already take is accepted. Sector-grid bytes are multiples of 4
#           (docs/passability-findings.md F12), so in practice this is 0x08 (grass) and
#           0x0C (forest) — both proven passable for the player by the same live walk (F11).
# func 21CD..21D0  len 0004 B  evidence: seed+reko
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_21cd:
L_0023cd:
        cmp    $0x14,%al
L_0023cf:
        jb L_0023e2
