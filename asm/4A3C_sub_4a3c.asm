# sub_4a3c — the return of the asm/4A1C_screen_clear_mode1 prologue: `pop %ax ; ret`. Two
#           bytes, and they are the proof that 4A1C..4A3D is one routine rather than four
#           fragments — the `push %ax` at asm/4A1C is answered here, three files later, and
#           nothing else in the run contains a `ret`. Called from the startup region
#           nothing else in the run contains a `ret`. There are 11 `call` sites to 4A1C across
#           8 files — the startup region (asm/0100, asm/013E), cmd_Z, asm/5400 and four others.
# func 4A3C..4A3D  len 0002 B  evidence: seed+reko
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_4a3c:
L_004c3c:
        pop    %ax
L_004c3d:
        ret
