# sub_37ae — mechanical clean (bulk wave); behavior not yet reviewed
# func 37AE..37DB  len 002E B  evidence: seed+reko
# calls: L_000c30, L_000c33, L_0051df (str_out)
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_37ae:
L_0039ae:
        mov    0x64,%al
L_0039b1:
        .byte 0x0a,0xc0  # forced-kept: gas re-encodes 'or     %al,%al' differently
L_0039b3:
        jne L_0039c8
L_0039b5:
        call L_0051df
        db 0x8d,"NONE OWNED!",0x00        # string
L_0039c5:
        jmp L_000c30
L_0039c8:
        stc
L_0039c9:
        mov    0x64,%al
L_0039cc:
        cmc
L_0039cd:
        sbb    $0x1,%al
L_0039cf:
        das
L_0039d0:
        cmc
L_0039d1:
        mov    %al,0x64
L_0039d4:
        mov    $0x96,%al
L_0039d6:
        mov    %al,0x26
L_0039d9:
        jmp L_000c33
