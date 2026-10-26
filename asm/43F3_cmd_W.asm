# cmd_W — command handler 'W' (WEAR ARMOUR): armour menu "WEAR ARMOUR:\r1-CLOTH,
#           2-LEATHER, 3-CHAIN,\r4-PLATE, 5-REFLECT, 6-POWER,\rWHICH? \0";
#           errors " NOT OWNED!" and " <-THOU ART NOT\rSTRONG ENOUGH TO WEAR!";
#           success prints " READY."
# func 43F3..44D3  len 00E1 B  evidence: seed+reko (jump table cs:0730 entry W)
# provenance: static
#           entry never appears in ExecutedInstructions of any of the 149 harvests; derived by tools/provenance_from_traces.py
# confidence: medium (flow + messages proven by bytes; NPC/quest semantics inferred)
# notes: re-decoded with tools/decode_str.py (str_out-aware); gas re-encode diffs
#        kept as .byte (disp8/disp16 and reg-op form choices)
cmd_W:
cmd_W:
L_0045f3:
        call L_0051df
        db "WEAR ARMOUR:",0x0d,"1-CLOTH, 2-LEATHER, 3-CHAIN,",0x0d,"4-PLATE, 5-REFLECT, 6-POWER,",0x0d,"WHICH? ",0x00        # string
L_004645:
        call L_002228
L_004648:
        mov    %al,0x1f
L_00464b:
        cmp    $0x7,%al
L_00464d:
        jb L_004654
L_00464f:
        mov    $0x0,%al
L_004651:
        mov    %al,0x1f
L_004654:
        nop
L_004655:
        clc
L_004656:
        adc    $0x1d,%al
L_004658:
        call L_00528c
L_00465b:
        mov    $0x0,%bh
L_00465d:
        mov    0x1f,%bl
L_004661:
        .byte 0x8b,0xfb  # forced-kept: gas re-encodes 'mov    %bx,%di' differently
L_004663:
        mov    0x96(%di),%al
L_004667:
        .byte 0x0a,0xc0  # forced-kept: gas re-encodes 'or     %al,%al' differently
L_004669:
        jne L_004684
L_00466b:
        mov    0x1f,%al
L_00466e:
        .byte 0x0a,0xc0  # forced-kept: gas re-encodes 'or     %al,%al' differently
L_004670:
        je L_004684
L_004672:
        call L_0051df
        db " NOT OWNED!",0x00        # string
L_004681:
        jmp L_000c33
L_004684:
        mov    0x1f,%al
L_004687:
        .byte 0x02,0xc0  # forced-kept: gas re-encodes 'add    %al,%al' differently
L_004689:
        .byte 0x02,0xc0  # forced-kept: gas re-encodes 'add    %al,%al' differently
L_00468b:
        .byte 0x02,0xc0  # forced-kept: gas re-encodes 'add    %al,%al' differently
L_00468d:
        cmp    0x4b,%al
L_004691:
        jb L_0046c0
L_004693:
        call L_0051df
        db " <-THOU ART NOT",0x0d,"STRONG ENOUGH TO WEAR!",0x00        # string
L_0046bd:
        jmp L_000c33
L_0046c0:
        call L_0051df
        db " READY.",0x00        # string
L_0046cb:
        mov    0x1f,%al
L_0046ce:
        mov    %al,0x62
L_0046d1:
        jmp L_000c33
