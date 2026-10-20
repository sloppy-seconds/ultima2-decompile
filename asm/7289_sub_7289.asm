# sub_7289 — mechanical clean (bulk wave); behavior not yet reviewed
# func 7289..729F  len 0017 B  evidence: call+reko
# calls: L_005ee4
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_7289:
L_007489:
        nop
L_00748a:
        cmpb   $0x0,%cs:0x6998
L_007490:
        jne L_00749b
L_007492:
        call L_005ee4
L_007495:
        movb   $0xff,%cs:0x6998
L_00749b:
        ret
L_00749c:
        add    %al,(%bx,%si)
        db 0x00,0x00        # tail-pad
