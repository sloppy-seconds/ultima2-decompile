# sub_4fd3 — key_poll tail, lower-bound half of the upper-case: bytes below 0x61 return
#           untouched, which is why the four arrow codes (all <= 0x19) pass through unchanged.
# func 4FD3..4FD6  len 0004 B  evidence: seed+reko
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_4fd3:
L_0051d3:
        cmp    $0x61,%al
L_0051d5:
        jb L_0051dd
