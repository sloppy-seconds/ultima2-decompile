# offer_only_outdoors_earth — the two save guards: outdoors, and DS:6D clear
# name-evidence: strings 'ONLY OUTDOORS!' / 'ONLY ON EARTH!'
# MEASURED 2026-10-29 (captures/spice86/save-wilderness), in this order:
#           inside a town, Q prints 'ONLY OUTDOORS!' and writes nothing; outdoors with
#           DS:6D != 0 it prints 'ONLY ON EARTH!' and writes nothing; outdoors with
#           DS:6D == 0 the save proceeds and writes player AND mapxNN AND monxNN of the
#           standing sector. The gate is the same shape as asm/22FD: `mov 0x6d,%al ;
#           or %al,%al ; je` -- non-zero refuses.
# WHY THIS MATTERS: a maxed test character holds boots, DS:6D reads 0x01, and every Q it
#           makes is refused with a sentence that sounds like a rule about the world. That
#           refusal is why an earlier measurement concluded the game never writes sector
#           files at all. It does; the save just had not run. Forcing DS:6D = 0 with a poke
#           made the same Q succeed immediately.
# OPEN: what DS:6D IS. state.h names it boots_count and marks it a STALE COPY; an earlier
#           session already flagged the contradiction. Behaviour is measured, identity is not.
#           docs/needs-gameplay.md G44.
# func 3DFA..3E4F  len 0056 B  evidence: seed+reko
# calls: L_000c30, L_000c33, L_0024fd, L_0051df (str_out)
# provenance: live:play-test (+2 other harvests), static; the two refusals and the accepted
#           save are from the 2026-10-29 save-wilderness session
# confidence: high for the behaviour (both refusals and the accepted save were observed with
#           screenshots); low for what DS:6D means
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
offer_only_outdoors_earth:
L_003ffa:
        mov    0x6d,%al
L_003ffd:
        .byte 0x0a,0xc0  # forced-kept: gas re-encodes 'or     %al,%al' differently
L_003fff:
        je L_004017
L_004001:
        call L_0051df
        db 0x8d,"ONLY ON EARTH!",0x00        # string
L_004014:
        jmp L_000c30
L_004017:
        mov    0x13,%al
L_00401a:
        cmp    $0x78,%al
L_00401c:
        jae L_004033
L_00401e:
        call L_0051df
        db 0x8d,"ONLY ON FOOT!",0x00        # string
L_004030:
        jmp L_000c30
L_004033:
        call L_0051df
        db 0x8d,"ONE MOMENT PLEASE!",0x00        # string
L_00404a:
        call L_0024fd
L_00404d:
        jmp L_000c33
