# sub_3ed4 — mechanical clean (bulk wave); behavior not yet reviewed
# func 3ED4..3F24  len 0051 B  evidence: seed+reko
# strings: " <-THOU ART NOT "; " READY."
# calls: L_000c33, L_0051df (str_out)
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_3ed4:
L_0040d4:
        mov    0x1f,%al
L_0040d7:
        .byte 0x02,0xc0  # forced-kept: gas re-encodes 'add    %al,%al' differently
L_0040d9:
        .byte 0x02,0xc0  # forced-kept: gas re-encodes 'add    %al,%al' differently
L_0040db:
        .byte 0x02,0xc0  # forced-kept: gas re-encodes 'add    %al,%al' differently
L_0040dd:
        cmp    0x4c,%al
L_0040e1:
        jb L_004111
L_0040e3:
        call L_0051df
        db " <-THOU ART NOT ",0x8d,"AGILE ENOUGH TO WIELD!",0x00        # string
L_00410e:
        jmp L_000c33
L_004111:
        call L_0051df
        db " READY.",0x00        # string
L_00411c:
        mov    0x1f,%al
L_00411f:
        mov    %al,0x61
L_004122:
        jmp L_000c33
