# sub_21f7 — the step gate's ACCEPT return: AL = 0, and the cmp before the ret is what sets
#           ZF for the callers at asm/2150, asm/2169 and asm/2189.
# func 21F7..21FB  len 0005 B  evidence: seed+reko
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_21f7:
L_0023f7:
        mov    $0x0,%al
L_0023f9:
        cmp    $0x0,%al
L_0023fb:
        ret
