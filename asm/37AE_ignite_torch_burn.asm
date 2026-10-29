# ignite_torch_burn — the torch spend and the light refill, plus the NONE OWNED! refusal
# name-evidence: the body of asm/3794 cmd_I, which the Phase 2 map cut after the `e8` opcode.
#           Reached when the site kind is >= 4. Reads [DS:64] (torches, packed decimal), prints
#           NONE OWNED! and returns if it is zero, otherwise spends one torch with the usual
#           `stc; cmc; sbb $1; das; cmc` and writes 0x96 into [DS:26].
# func 37AE..37DB  len 002E B  evidence: seed+reko; role read from the bytes 2026-10-29
# calls: L_000c30, L_000c33, L_0051df (str_out)
# provenance: static bytes, decoded 2026-10-29 alongside asm/3794 and asm/3795
# confidence: high
# notes: [DS:26] is ALIASED. Outside a site the walk loop uses it as a moved-since-command flag;
#           inside one asm/1151 uses it as the light counter, printing IT'S DARK! at zero and
#           TORCH BURNED OUT! when a step takes it there. The LIGHT spell in asm/3139 writes the
#           same 0x96 into the same byte, so a torch and that spell are ONE running count —
#           casting LIGHT in a lit corridor spends a spell to refill a torch that is already
#           burning. Confirmed live in captures/spice86/cmd-c-cast-tower (0x96 on cast, then
#           0x95 and 0x94 on the two steps after). Anyone reading moved_flag must know which
#           mode they are in.
# label: sub_37ae / L_0039ae kept as they are — labels are body (AGENTS.md § 3).
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
