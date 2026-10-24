# sub_2155 — first fallback guard: if DS:1A == 0 the vertical-only cell would be identical to
#           the diagonal one already refused, so skip to the horizontal retry at asm/216E.
# func 2155..215B  len 0007 B  evidence: seed+reko
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_2155:
L_002355:
        mov    0x1a,%al
L_002358:
        cmp    $0x0,%al
L_00235a:
        je L_00236e
