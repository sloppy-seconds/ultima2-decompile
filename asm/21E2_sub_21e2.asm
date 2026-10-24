# sub_21e2 — the step gate's ACCEPT landing pad, and the site guard. Every accept branch
#           (asm/21B6, asm/21CD, asm/21D1, asm/21DF) arrives here. If DS:4A == 0 the accept
#           stands; otherwise the two edge tests follow, so inside a settlement the wrapped
#           edge row and column are walls even though asm/212E masked the coordinate with 0x3F.
# func 21E2..21E8  len 0007 B  evidence: seed+reko
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_21e2:
L_0023e2:
        mov    0x4a,%al
L_0023e5:
        cmp    $0x0,%al
L_0023e7:
        je L_0023f7
