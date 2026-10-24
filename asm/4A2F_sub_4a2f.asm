# sub_4a2f — part of the asm/4A1C_screen_clear_mode1 prologue: set DS:31 to 40 and clear
#           DS:478, then call L_0055d9. Not a routine — the run 4A1C..4A3D is one function
#           (4 fragments, one ret), and the `push %ax` three files back is answered by the
#           `pop %ax` in asm/4A3C. Confirmed by tools/fragment_splits.py on 2026-10-28d.
# func 4A2F..4A3B  len 000D B  evidence: seed+reko
# calls: L_0055d9
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_4a2f:
L_004c2f:
        movb   $0x28,0x31
L_004c34:
        movb   $0x0,0x478
L_004c39:
        call L_0055d9
