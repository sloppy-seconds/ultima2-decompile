# sub_4f58 — key_poll swallow, first of three: AL == 0x05 is Ctrl-E, one of the four arrow
#           direction codes. Typed, it must not move the character.
# func 4F58..4F5B  len 0004 B  evidence: seed+reko
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_4f58:
L_005158:
        cmp    $0x5,%al
L_00515a:
        je L_005164
