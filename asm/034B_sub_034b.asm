# sub_034b — mechanical clean (bulk wave); behavior not yet reviewed
# func 034B..0373  len 0029 B  evidence: reko
# strings: "'C' - CREATE A NEW CHARACTER"
# calls: L_0051df (str_out)
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_034b:
L_00054b:
        push   %es
L_00054c:
        das
L_00054d:
        add    %dl,(%bx,%di)
L_00054f:
        mov    $0x6,%al
L_000551:
        mov    %al,0x2e
L_000554:
        call L_0051df
        db "'C' - CREATE A NEW CHARACTER",0x00        # string
