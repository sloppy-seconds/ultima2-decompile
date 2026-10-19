# sub_0375 — mechanical clean (bulk wave); behavior not yet reviewed
# func 0375..0388  len 0014 B  evidence: reko
# strings: "CHOICE:"
# calls: L_0051df (str_out)
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_0375:
L_000575:
        push   %es
L_000576:
        das
L_000577:
        add    %dl,(%bp,%di)
L_000579:
        mov    $0x5,%al
L_00057b:
        mov    %al,0x2e
L_00057e:
        call L_0051df
        db "CHOICE:",0x00        # string
