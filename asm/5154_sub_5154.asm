# sub_5154 — mechanical clean (bulk wave); behavior not yet reviewed
# func 5154..5166  len 0013 B  evidence: seed+reko
# strings: "EXP.="
# calls: L_0051df (str_out)
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_5154:
L_005354:
        mov    $0x1e,%al
L_005356:
        mov    %al,0x2e
L_005359:
        movb   $0x16,0x2f
L_00535e:
        call L_0051df
        db "EXP.=",0x00        # string
