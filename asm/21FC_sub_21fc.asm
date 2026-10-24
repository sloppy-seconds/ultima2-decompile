# sub_21fc — the step gate's REFUSE return: AL = 0xFF with ZF clear. Every refusal in this
#           function ends here, including the DS:26A clause and the site guard.
# func 21FC..2200  len 0005 B  evidence: seed+reko
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_21fc:
L_0023fc:
        mov    $0xff,%al
L_0023fe:
        cmp    $0x0,%al
L_002400:
        ret
