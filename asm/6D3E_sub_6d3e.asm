# sub_6d3e — mechanical clean (bulk wave); behavior not yet reviewed
# func 6D3E..6D5A  len 001D B  evidence: call+reko
# calls: L_006f5b, L_006f68
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_6d3e:
L_006f3e:
        call L_006f5b
L_006f41:
        mov    $0x0,%bh
L_006f43:
        mov    $0x3f,%bl
L_006f45:
        .byte 0x8b,0xf3  # forced-kept: gas re-encodes 'mov    %bx,%si' differently
L_006f47:
        call L_006f68
L_006f4a:
        mov    %al,0x4cd(%si)
L_006f4e:
        call L_006f68
L_006f51:
        and    $0x7f,%al
L_006f53:
        mov    %al,0x50d(%si)
L_006f57:
        dec    %si
L_006f58:
        jns L_006f47
L_006f5a:
        ret
