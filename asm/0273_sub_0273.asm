# sub_0273 — mechanical clean (bulk wave); behavior not yet reviewed
# func 0273..0286  len 0014 B  evidence: reko
# strings: "OF  THE"
# calls: L_0051df (str_out)
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_0273:
L_000473:
        push   %es
L_000474:
        das
L_000475:
        add    %al,(%di)
L_000477:
        mov    $0x10,%al
L_000479:
        mov    %al,0x2e
L_00047c:
        call L_0051df
        db "OF  THE",0x00        # string
