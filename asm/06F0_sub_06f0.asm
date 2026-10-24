# sub_06f0 — part of the asm/06ED scale: compares the clock window's pass count DS:74 against
#           DS:554 and, if it is at least that, multiplies by a table entry at DS:558(%bx) and
#           divides by DS:554. See asm/06ED for what that is probably for.
# func 06F0..06F8  len 0009 B  evidence: seed+reko
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_06f0:
L_0008f0:
        mov    0x74,%ax
L_0008f3:
        sub    0x554,%ax
L_0008f7:
        jae L_0008ff
