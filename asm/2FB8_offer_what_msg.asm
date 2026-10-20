# offer_what_msg — OFFER needs a target word
# name-evidence: string ' WHAT?' in cmd_O chain
# func 2FB8..2FCC  len 0015 B  evidence: seed+reko
# strings: " WHAT?"
# calls: L_000c30, L_0051df (str_out)
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
offer_what_msg:
L_0031b8:
        cmp    $0x26,%al
L_0031ba:
        je L_0031d0
L_0031bc:
        cmp    $0x28,%al
L_0031be:
        je L_0031d3
L_0031c0:
        call L_0051df
        db " WHAT?",0x00        # string
L_0031ca:
        jmp L_000c30
