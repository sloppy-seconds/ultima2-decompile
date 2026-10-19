# sub_40cb — mechanical clean (bulk wave); behavior not yet reviewed
# func 40CB..40D3  len 0009 B  evidence: seed+reko
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_40cb:
L_0042cb:
        nop
L_0042cc:
        mov    0x197(%di),%al
L_0042d0:
        cmp    $0x6c,%al
L_0042d2:
        jne L_0042d7
