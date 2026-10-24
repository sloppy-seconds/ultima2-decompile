# sub_21e9 — site guard, first half: candidate x (DS:23) == 0 is refused when DS:4A != 0.
# func 21E9..21EF  len 0007 B  evidence: seed+reko
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_21e9:
L_0023e9:
        mov    0x23,%al
L_0023ec:
        cmp    $0x0,%al
L_0023ee:
        je L_0023fc
