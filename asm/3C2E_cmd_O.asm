# cmd_O — command handler 'O' (OFFER): offers gold to NPCs; "OFFER GOLD
#           DIRECT-", "OFFER TO WHOM?", "HOW MUCH (*100) ?"; special
#           recipients: "ENILNO IS YOURS!" / "EARN THE RING!" / "THE RING IS
#           YOURS!" / "HERE TAKE THIS!" / "ALAKAZAM!" quest messages.
# func 3C2E..3DBB  len 018E B  evidence: seed+reko (jump table cs:0730 entry O)
# provenance: live:cmd-letters2-20261025; static
#           entry executed in 2 of 171 harvests; confirmed by the capture of 2026-10-25. The
#           capture proves the entry ran and nothing more -- the OFFER TO WHOM? / HOW MUCH
#           flow needs a town with NPCs and is not covered by these harvests. Was recorded as
#           never executed against a 60-harvest corpus that has since grown.
# confidence: medium (flow + messages proven by bytes; NPC/quest semantics inferred)
# notes: re-decoded with tools/decode_str.py (str_out-aware); gas re-encode diffs
#        kept as .byte (disp8/disp16 and reg-op form choices)
# reads: [DI+0x1D7] with DI = [DS:1F] (the cursor slot) at L_003e9d and L_003eda. This
#        is the routine that gives that field its shape: bit 7 clear takes the generic
#        `THANK YOU VERY MUCH!`, bit 7 set requires [DS:4A]==2 && [DS:49]==3 and then
#        ENUMERATES 0x81 -> `ENILNO IS YOURS!` (+[DS:7F]=1), 0x82 -> `EARN THE RING!`
#        or `THE RING IS YOURS!` (+[DS:D6]=1, the RING slot of CP5 C5), 0x83 -> a third
#        recipient. Because the high values are compared one by one, [DI+0x1D7] is a
#        role/identity byte, not a flag-and-count pair, and bit 7 is not aggro.
#        See docs/monster-spawn.md § 6.
cmd_O:
cmd_O:
L_003e2e:
        call L_0051df
        db "OFFER GOLD DIRECT-",0x00        # string
L_003e44:
        call L_002562
L_003e47:
        call L_0025e6
L_003e4a:
        .byte 0x8b,0xdf  # forced-kept: gas re-encodes 'mov    %di,%bx' differently
L_003e4c:
        mov    %bl,0x1f
L_003e50:
        mov    $0x8d,%al
L_003e52:
        call L_0055f4
L_003e55:
        .byte 0x8b,0xdf  # forced-kept: gas re-encodes 'mov    %di,%bx' differently
L_003e57:
        cmp    $0x0,%bl
L_003e5a:
        jne L_003e71
L_003e5c:
        call L_0051df
        db "OFFER TO WHOM?",0x00        # string
L_003e6e:
        jmp L_000c33
L_003e71:
        call L_0051df
        db "HOW MUCH (*100) ? ",0x00        # string
L_003e87:
        call L_002228
L_003e8a:
        mov    %al,0x27
L_003e8d:
        mov    $0x0,%al
L_003e8f:
        mov    %al,0x28
L_003e92:
        call L_002252
L_003e95:
        mov    $0x0,%bh
L_003e97:
        mov    0x1f,%bl
L_003e9b:
        .byte 0x8b,0xfb  # forced-kept: gas re-encodes 'mov    %bx,%di' differently
L_003e9d:
        mov    0x1d7(%di),%al
L_003ea1:
        .byte 0x0a,0xc0  # forced-kept: gas re-encodes 'or     %al,%al' differently
L_003ea3:
        jns L_003eb6
L_003ea5:
        mov    0x4a,%al
L_003ea8:
        cmp    $0x2,%al
L_003eaa:
        jne L_003eb6
L_003eac:
        mov    0x49,%al
L_003eaf:
        cmp    $0x3,%al
L_003eb1:
        jne L_003eb6
L_003eb3:
        jmp L_003ed2
L_003eb5:
        nop
L_003eb6:
        nop
L_003eb7:
        call L_0051df
        db "THANK YOU VERY MUCH!",0x00        # string
L_003ecf:
        jmp L_000c33
L_003ed2:
        mov    $0x0,%bh
L_003ed4:
        mov    0x1f,%bl
L_003ed8:
        .byte 0x8b,0xfb  # forced-kept: gas re-encodes 'mov    %bx,%di' differently
L_003eda:
        mov    0x1d7(%di),%al
L_003ede:
        cmp    $0x81,%al
L_003ee0:
        je L_003eed
L_003ee2:
        cmp    $0x82,%al
L_003ee4:
        je L_003f10
L_003ee6:
        cmp    $0x83,%al
L_003ee8:
        je L_003f52
L_003eea:
        jmp L_003f7e
L_003eed:
        mov    0x27,%al
L_003ef0:
        cmp    $0x5,%al
L_003ef2:
        jb L_003eb6
L_003ef4:
        call L_0051df
        db "ENILNO IS YOURS!",0x00        # string
L_003f08:
        mov    $0x1,%al
L_003f0a:
        mov    %al,0x7f
L_003f0d:
        jmp L_000c33
L_003f10:
        mov    0x27,%al
L_003f13:
        cmp    $0x5,%al
L_003f15:
        jb L_003eb6
L_003f17:
        mov    0x6c,%al
L_003f1a:
        .byte 0x0a,0xc0  # forced-kept: gas re-encodes 'or     %al,%al' differently
L_003f1c:
        jne L_003f33
L_003f1e:
        call L_0051df
        db "EARN THE RING!",0x00        # string
L_003f30:
        jmp L_000c33
L_003f33:
        nop
L_003f34:
        call L_0051df
        db "THE RING IS YOURS!",0x00        # string
L_003f4a:
        mov    $0x1,%al
L_003f4c:
        mov    %al,0xd6
L_003f4f:
        jmp L_000c33
L_003f52:
        call L_005417
L_003f55:
        and    $0x7,%al
L_003f57:
        clc
L_003f58:
        mov    $0x0,%ah
L_003f5a:
        .byte 0x8b,0xf8  # forced-kept: gas re-encodes 'mov    %ax,%di' differently
L_003f5c:
        inc    %di
L_003f5d:
        .byte 0x8a,0x85,0x76,0x00  # forced-kept: gas re-encodes 'mov    0x76(%di),%al' differently
L_003f61:
        adc    $0x1,%al
L_003f63:
        daa
L_003f64:
        .byte 0x88,0x85,0x76,0x00  # forced-kept: gas re-encodes 'mov    %al,0x76(%di)' differently
L_003f68:
        call L_0051df
        db "HERE TAKE THIS!",0x00        # string
L_003f7b:
        jmp L_000c33
L_003f7e:
        call L_005417
L_003f81:
        and    $0x7,%al
L_003f83:
        cmp    $0x6,%al
L_003f85:
        jb L_003f8a
L_003f87:
        jmp L_003eb6
L_003f8a:
        nop
L_003f8b:
        mov    $0x0,%ah
L_003f8d:
        .byte 0x8b,0xf8  # forced-kept: gas re-encodes 'mov    %ax,%di' differently
L_003f8f:
        clc
L_003f90:
        .byte 0x8a,0x85,0x4b,0x00  # forced-kept: gas re-encodes 'mov    0x4b(%di),%al' differently
L_003f94:
        adc    0x27,%al
L_003f98:
        daa
L_003f99:
        adc    0x27,%al
L_003f9d:
        daa
L_003f9e:
        adc    0x27,%al
L_003fa2:
        daa
L_003fa3:
        adc    0x27,%al
L_003fa7:
        daa
L_003fa8:
        .byte 0x88,0x85,0x4b,0x00  # forced-kept: gas re-encodes 'mov    %al,0x4b(%di)' differently
L_003fac:
        call L_0051df
        db "ALAKAZAM!",0x00        # string
L_003fb9:
        jmp L_000c33
