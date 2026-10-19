# sub_025e — mechanical clean (bulk wave); behavior not yet reviewed
# func 025E..0271  len 0014 B  evidence: reko
# strings: "REVENGE"
# calls: L_0051df (str_out)
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_025e:
L_00045e:
        push   %es
L_00045f:
        das
L_000460:
        add    %al,(%bp,%di)
L_000462:
        mov    $0x10,%al
L_000464:
        mov    %al,0x2e
L_000467:
        call L_0051df
        db "REVENGE",0x00        # string
