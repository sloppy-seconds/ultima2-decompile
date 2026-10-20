# sub_0288 — mechanical clean (bulk wave); behavior not yet reviewed
# func 0288..029F  len 0018 B  evidence: reko
# strings: "ENCHANTRESS"
# calls: L_0051df (str_out)
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_0288:
L_000488:
        push   %es
L_000489:
        das
L_00048a:
        add    %al,(%bx)
L_00048c:
        mov    $0xe,%al
L_00048e:
        mov    %al,0x2e
L_000491:
        call L_0051df
        db "ENCHANTRESS",0x00        # string
