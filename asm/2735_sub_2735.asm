# sub_2735 — mechanical clean (bulk wave); behavior not yet reviewed
# DECODED 2026-10-29 (listing only): the match path. Reached when asm/2731 finds `0xC0` at the
#           candidate cell. It zeroes BX and copies it to SI, then `mov 0x70,%al ; mov 0x6,%bx ;
#           mov %al,(%bx,%si)` stores DS:70 into DS:06 — a write through a register pair, which
#           is why a grep for direct stores to DS:06 does not find it.
#           NOT DECODED: what DS:70 is, what DS:06 is, and therefore what this accomplishes. It
#           is deliberately left unnamed rather than guessed at; the live gate transit in
#           docs/moongates.md § 1 changes DS:49 and the position, and neither is obviously DS:06.
#           Causal link to the observed rotation unproven — see asm/2708.
# func 2735..2743  len 000F B  evidence: seed+reko
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_2735:
L_002935:
        mov    $0x0,%bh
L_002937:
        mov    $0x0,%bl
L_002939:
        .byte 0x8b,0xf3  # forced-kept: gas re-encodes 'mov    %bx,%si' differently
L_00293b:
        mov    0x70,%al
L_00293e:
        mov    0x6,%bx
L_002942:
        mov    %al,(%bx,%si)
