# sub_5287 — mechanical clean (bulk wave); behavior not yet reviewed
# func 5287..52C9  len 0043 B  evidence: seed+reko
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_5287:
L_005487:
        .byte 0xc3  # forced-kept: gas re-encodes 'ret' differently
L_005488:
        .byte 0x04,0x10  # forced-kept: gas re-encodes 'add    $0x10,%al' differently
L_00548a:
        .byte 0x00,0x0f  # forced-kept: gas re-encodes 'add    %cl,(%bx)' differently
L_00548c:
        .byte 0xf0,0x00,0x00  # forced-kept: gas re-encodes 'lock add %al,(%bx,%si)' differently
L_00548f:
        .byte 0xff  # forced-kept: gas re-encodes '(bad)' differently
L_005490:
        .byte 0xff,0x00  # forced-kept: gas re-encodes 'incw   (%bx,%si)' differently
L_005492:
        .byte 0x03,0xff  # forced-kept: gas re-encodes 'add    %di,%di' differently
L_005494:
        .byte 0xff,0xc0  # forced-kept: gas re-encodes 'inc    %ax' differently
L_005496:
        .byte 0x0f,0xff,0xff  # forced-kept: gas re-encodes 'ud0    %di,%di' differently
L_005499:
        .byte 0xf0,0x0f,0xff,0xff  # forced-kept: gas re-encodes 'lock ud0 %di,%di' differently
L_00549d:
        .byte 0xf0,0x3f  # forced-kept: gas re-encodes 'lock aas' differently
L_00549f:
        .byte 0xff  # forced-kept: gas re-encodes '(bad)' differently
L_0054a0:
        .byte 0xff  # forced-kept: gas re-encodes '(bad)' differently
L_0054a1:
        .byte 0xfc  # forced-kept: gas re-encodes 'cld' differently
L_0054a2:
        .byte 0x3f  # forced-kept: gas re-encodes 'aas' differently
L_0054a3:
        .byte 0xff  # forced-kept: gas re-encodes '(bad)' differently
L_0054a4:
        .byte 0xff  # forced-kept: gas re-encodes '(bad)' differently
L_0054a5:
        .byte 0xfc  # forced-kept: gas re-encodes 'cld' differently
L_0054a6:
        .byte 0x3f  # forced-kept: gas re-encodes 'aas' differently
L_0054a7:
        .byte 0xff  # forced-kept: gas re-encodes '(bad)' differently
L_0054a8:
        .byte 0xff  # forced-kept: gas re-encodes '(bad)' differently
L_0054a9:
        .byte 0xfc  # forced-kept: gas re-encodes 'cld' differently
L_0054aa:
        .byte 0x3f  # forced-kept: gas re-encodes 'aas' differently
L_0054ab:
        .byte 0xff  # forced-kept: gas re-encodes '(bad)' differently
L_0054ac:
        .byte 0xff  # forced-kept: gas re-encodes '(bad)' differently
L_0054ad:
        .byte 0xfc  # forced-kept: gas re-encodes 'cld' differently
L_0054ae:
        .byte 0x3f  # forced-kept: gas re-encodes 'aas' differently
L_0054af:
        .byte 0xff  # forced-kept: gas re-encodes '(bad)' differently
L_0054b0:
        .byte 0xff  # forced-kept: gas re-encodes '(bad)' differently
L_0054b1:
        .byte 0xfc  # forced-kept: gas re-encodes 'cld' differently
L_0054b2:
        .byte 0x3f  # forced-kept: gas re-encodes 'aas' differently
L_0054b3:
        .byte 0xff  # forced-kept: gas re-encodes '(bad)' differently
L_0054b4:
        .byte 0xff  # forced-kept: gas re-encodes '(bad)' differently
L_0054b5:
        .byte 0xfc  # forced-kept: gas re-encodes 'cld' differently
L_0054b6:
        .byte 0x0f,0xff,0xff  # forced-kept: gas re-encodes 'ud0    %di,%di' differently
L_0054b9:
        .byte 0xf0,0x0f,0xff,0xff  # forced-kept: gas re-encodes 'lock ud0 %di,%di' differently
L_0054bd:
        .byte 0xf0,0x03,0xff  # forced-kept: gas re-encodes 'lock add %di,%di' differently
L_0054c0:
        .byte 0xff,0xc0  # forced-kept: gas re-encodes 'inc    %ax' differently
L_0054c2:
        .byte 0x00,0xff  # forced-kept: gas re-encodes 'add    %bh,%bh' differently
L_0054c4:
        .byte 0xff,0x00  # forced-kept: gas re-encodes 'incw   (%bx,%si)' differently
L_0054c6:
        .byte 0x00,0x0f  # forced-kept: gas re-encodes 'add    %cl,(%bx)' differently
L_0054c8:
        .byte 0xf0,0x00  # forced-kept: gas re-encodes 'lock add %bl,-0x7d(%bp,%di)' differently
