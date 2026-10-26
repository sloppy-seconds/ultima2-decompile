# cmd_X — command handler 'X' (X-IT / destroy item): "X-IT", " WHAT?",
#           "-NOT HERE!" paths.
# func 44D4..4541  len 006E B  evidence: seed+reko (jump table cs:0730 entry X)
# provenance: live:airport32 (+2 other harvests), static
#           entry executed in 3 of 153 harvests; derived by tools/provenance_from_traces.py
# confidence: medium (flow + messages proven by bytes; NPC/quest semantics inferred)
# notes: re-decoded with tools/decode_str.py (str_out-aware); gas re-encode diffs
#        kept as .byte (disp8/disp16 and reg-op form choices)
cmd_X:
cmd_X:
L_0046d4:
        call L_0051df
        db "X-IT",0x00        # string
L_0046dc:
        mov    0x13,%al
L_0046df:
        cmp    $0x78,%al
L_0046e1:
        jb L_0046f0
L_0046e3:
        call L_0051df
        db " WHAT?",0x00        # string
L_0046ed:
        jmp L_000c30
L_0046f0:
        .byte 0x90  # forced-kept: gas re-encodes 'nop' differently
L_0046f1:
        .byte 0xa0,0x00,0x00  # forced-kept: gas re-encodes 'mov    0x0,%al' differently
L_0046f4:
        .byte 0xa2,0x23,0x00  # forced-kept: gas re-encodes 'mov    %al,0x23' differently
L_0046f7:
        mov    0x1,%al
L_0046fa:
        mov    %al,0x24
L_0046fd:
        call L_0052b3
L_004700:
        mov    0x14,%al
L_004703:
        cmp    $0x4,%al
L_004705:
        je L_004723
L_004707:
        cmp    $0x0,%al
L_004709:
        jne L_004712
L_00470b:
        mov    0x13,%al
L_00470e:
        cmp    $0x24,%al
L_004710:
        je L_004723
L_004712:
        call L_0051df
        db "-NOT HERE!",0x00        # string
L_004720:
        jmp L_000c30
L_004723:
        mov    0x13,%al
L_004726:
        .byte 0x02,0xc0  # forced-kept: gas re-encodes 'add    %al,%al' differently
L_004728:
        mov    $0x0,%bh
L_00472a:
        mov    $0x0,%bl
L_00472c:
        .byte 0x8b,0xf3  # forced-kept: gas re-encodes 'mov    %bx,%si' differently
L_00472e:
        mov    0x6,%bx
L_004732:
        mov    %al,(%bx,%si)
L_004734:
        mov    0x47,%al
L_004737:
        .byte 0x02,0xc0  # forced-kept: gas re-encodes 'add    %al,%al' differently
L_004739:
        clc
L_00473a:
        adc    $0x78,%al
L_00473c:
        mov    %al,0x13
L_00473f:
        jmp L_000c33
