# sub_2201 — contact re-test, x half, on the candidate the step gate just accepted. This is
#           the SECOND contact test; the first is asm/0B25/asm/0B39 before the gate. It is not
#           redundant: the axis-substituted candidates from asm/215C and asm/216E can land on
#           the player where the diagonal candidate did not.
# func 2201..2209  len 0009 B  evidence: seed+reko
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_2201:
L_002401:
        mov    0x0,%al
L_002404:
        cmp    0x23,%al
L_002408:
        jne L_002416
