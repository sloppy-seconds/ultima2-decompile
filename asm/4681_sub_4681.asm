# sub_4681 — mechanical clean (bulk wave); behavior not yet reviewed
# func 4681..468D  len 000D B  evidence: reko
# calls: L_0053eb
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_4681:
L_004881:
        mov    $0x1,%bl
L_004883:
        .byte 0x8b,0xfb  # forced-kept: gas re-encodes 'mov    %bx,%di' differently
L_004885:
        mov    $0x0,%bh
L_004887:
        mov    $0x6,%bl
L_004889:
        .byte 0x8b,0xf3  # forced-kept: gas re-encodes 'mov    %bx,%si' differently
L_00488b:
        call L_0053eb
