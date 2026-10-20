# sub_0720 — mechanical clean (bulk wave); behavior not yet reviewed
# func 0720..0763  len 0044 B  evidence: seed+reko
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_0720:
L_000920:
        .byte 0xc3  # forced-kept: gas re-encodes 'ret' differently
        db 0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00        # fill
L_00092d:
        .byte 0x00,0x00  # forced-kept: gas re-encodes 'add    %al,(%bx,%si)' differently
L_00092f:
        .byte 0x00,0x8f,0x2b,0x6f  # forced-kept: gas re-encodes 'add    %cl,0x6f2b(%bx)' differently
L_000933:
        .byte 0x2f  # forced-kept: gas re-encodes 'das' differently
L_000934:
        .byte 0x0b,0x31  # forced-kept: gas re-encodes 'or     (%bx,%di),%si' differently
L_000936:
        .byte 0x4d  # forced-kept: gas re-encodes 'dec    %bp' differently
L_000937:
        .byte 0x33,0x89,0x33,0xc1  # forced-kept: gas re-encodes 'xor    -0x3ecd(%bx,%di),%cx' differently
L_00093b:
        .byte 0x35,0x3b,0x36  # forced-kept: gas re-encodes 'xor    $0x363b,%ax' differently
L_00093e:
        .byte 0x82,0x37,0x94  # forced-kept: gas re-encodes 'xorb   $0x94,(%bx)' differently
L_000941:
        .byte 0x37  # forced-kept: gas re-encodes 'aaa' differently
L_000942:
        .byte 0xdc,0x37  # forced-kept: gas re-encodes 'fdivl  (%bx)' differently
L_000944:
        .byte 0xf1  # forced-kept: gas re-encodes 'int1' differently
L_000945:
        .byte 0x37  # forced-kept: gas re-encodes 'aaa' differently
L_000946:
        .byte 0xb0,0x38  # forced-kept: gas re-encodes 'mov    $0x38,%al' differently
L_000948:
        .byte 0x92  # forced-kept: gas re-encodes 'xchg   %ax,%dx' differently
L_000949:
        .byte 0x3b,0xce  # forced-kept: gas re-encodes 'cmp    %si,%cx' differently
L_00094b:
        .byte 0x3b,0x2e,0x3c,0xbc  # forced-kept: gas re-encodes 'cmp    -0x43c4,%bp' differently
L_00094f:
        .byte 0x3d,0xc7,0x3d  # forced-kept: gas re-encodes 'cmp    $0x3dc7,%ax' differently
L_000952:
        .byte 0x50  # forced-kept: gas re-encodes 'push   %ax' differently
L_000953:
        .byte 0x3e,0x25,0x3f,0x50  # forced-kept: gas re-encodes 'ds and $0x503f,%ax' differently
L_000957:
        .byte 0x40  # forced-kept: gas re-encodes 'inc    %ax' differently
L_000958:
        .byte 0xf1  # forced-kept: gas re-encodes 'int1' differently
L_000959:
        .byte 0x42  # forced-kept: gas re-encodes 'inc    %dx' differently
L_00095a:
        jle L_00099f
L_00095c:
        .byte 0xf3,0x43  # forced-kept: gas re-encodes 'repz inc %bx' differently
L_00095e:
        .byte 0xd4,0x44  # forced-kept: gas re-encodes 'aam    $0x44' differently
L_000960:
        .byte 0x42  # forced-kept: gas re-encodes 'inc    %dx' differently
L_000961:
        .byte 0x45  # forced-kept: gas re-encodes 'inc    %bp' differently
L_000962:
        .byte 0x68,0x45  # forced-kept: gas re-encodes 'push   $0xe845' differently
