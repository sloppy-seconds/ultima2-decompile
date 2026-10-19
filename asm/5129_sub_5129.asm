# sub_5129 — mechanical clean (bulk wave); behavior not yet reviewed
# func 5129..513B  len 0013 B  evidence: seed+reko
# strings: "FOOD="
# calls: L_0051df (str_out)
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_5129:
L_005329:
        mov    $0x1e,%al
L_00532b:
        mov    %al,0x2e
L_00532e:
        movb   $0x15,0x2f
L_005333:
        call L_0051df
        db "FOOD=",0x00        # string
