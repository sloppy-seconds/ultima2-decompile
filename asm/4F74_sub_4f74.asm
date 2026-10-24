# sub_4f74 — typeahead drain, the loop back: any key after the first is consumed and thrown
#           away until the buffer is empty, then asm/4F76 restores the real one. This is why a
#           script that sends keys while the game is mid-turn loses them: the game discards
#           them on purpose, not the harness.
# func 4F74..4F75  len 0002 B  evidence: seed+reko
# calls: L_00516a
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_4f74:
L_005174:
        jmp L_00516a
