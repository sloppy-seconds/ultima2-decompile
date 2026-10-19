# sub_5175 — mechanical clean (bulk wave); behavior not yet reviewed
# func 5175..5187  len 0013 B  evidence: seed+reko
# strings: "GOLD="
# calls: L_0051df (str_out)
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_5175:
L_005375:
        mov    $0x1e,%al
L_005377:
        mov    %al,0x2e
L_00537a:
        movb   $0x17,0x2f
L_00537f:
        call L_0051df
        db "GOLD=",0x00        # string
