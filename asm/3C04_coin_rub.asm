# coin_rub — rub-a-coin secret (ENILNO path)
# name-evidence: string 'YOU RUB A COIN...'
# func 3C04..3C2D  len 002A B  evidence: seed+reko
# calls: L_000c33, L_0051df (str_out)
# apple2-twin: $7DC6 in ULTIMA.II.OBJ. Hand-decoded: `JSR $4006` then the inline string then
#           `LDA #$14 ; STA $D9` at $7DD9 — print, then store 20 into the creature-move freeze
#           counter, which is the same counter asm/2199_creature_step_gate refuses on and the
#           same constant this file stores to DS:26A. That is the second witness the behaviour
#           is intended and not a decode error. It used also to say that nobody had seen this
#           path run, and that is now withdrawn: cmd_N fell into it twice on 2026-10-29 in
#           captures/spice86/cmd-nr-live, with the coin spent, the string on a frame and DS:26A
#           read back at 0x14. The Apple II twin is corroboration, and the DOS entry is now
#           observed on its own terms.
#           Note this pair did NOT come from tools/apple2_anchor_map.py: the Apple text is
#           'You rub a coin....' (sentence case, four dots) against DOS 'YOU RUB A COIN...'
#           (upper, three dots), and the crosswalk matches verbatim only. Found by a targeted
#           search for the counter store.
# provenance: static
#           entry never appears in ExecutedInstructions of any of the 60 harvests; derived by tools/provenance_from_traces.py
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
coin_rub:
L_003e04:
        .byte 0xf9  # forced-kept: gas re-encodes 'stc' differently
L_003e05:
        .byte 0xa0,0xe3,0x00  # forced-kept: gas re-encodes 'mov    0xe3,%al' differently
L_003e08:
        .byte 0xf5  # forced-kept: gas re-encodes 'cmc' differently
L_003e09:
        .byte 0x1c,0x01  # forced-kept: gas re-encodes 'sbb    $0x1,%al' differently
L_003e0b:
        .byte 0x2f  # forced-kept: gas re-encodes 'das' differently
L_003e0c:
        .byte 0xf5  # forced-kept: gas re-encodes 'cmc' differently
L_003e0d:
        .byte 0xa2,0xe3,0x00  # forced-kept: gas re-encodes 'mov    %al,0xe3' differently
L_003e10:
        call L_0051df
        db 0x8d,"YOU RUB A COIN...",0x00        # string
L_003e26:
        .byte 0xb0,0x14  # forced-kept: gas re-encodes 'mov    $0x14,%al' differently
L_003e28:
        .byte 0xa2,0x6a,0x02  # forced-kept: gas re-encodes 'mov    %al,0x26a' differently
L_003e2b:
        jmp L_000c33
