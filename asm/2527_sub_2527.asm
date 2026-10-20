# sub_2527 — mechanical clean (bulk wave); behavior not yet reviewed
# func 2527..253A  len 0014 B  evidence: seed+reko
# strings: "--PARALIZED!"
# calls: L_0051df (str_out)
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_2527:
L_002727:
        call L_0051df
        db "--PARALIZED!",0x0d,0x00        # string
L_002738:
        .byte 0xb0,0xff  # forced-kept: gas re-encodes 'mov    $0xff,%al' differently
L_00273a:
        .byte 0xc3  # forced-kept: gas re-encodes 'ret' differently
