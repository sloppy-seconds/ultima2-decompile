# ready_weapon_agility_gate — the agility requirement on readying a weapon: digit*8 vs DS:4C,
#           refusal " <-THOU ART NOT \rAGILE ENOUGH TO WIELD!", success " READY." then DS:61 = digit
# RENAMED 2026-10-26 from 3ED4_sub_3ed4, on the strength of the decode below. Filename and header
#   only; `sub_3ed4` and every L_ label are body and were not touched (CP0).
# func 3ED4..3F24  len 0051 B  evidence: seed+reko
#
# THE RULE, read off the bytes:
#     al := DS:1F                       ; the digit just chosen
#     al := al * 8                      ; three `add %al,%al`
#     cmp DS:4C, al ; jb ok             ; success requires digit*8 STRICTLY BELOW the agility byte
#     print " <-THOU ART NOT \rAGILE ENOUGH TO WIELD!" ; jmp L_000c33
#   ok:
#     print " READY."
#     DS:61 := DS:1F                    ; the readied weapon index
#     jmp L_000c33
#
# It is the exact mirror of cmd_W's armour gate, and the symmetry is complete rather than
# suggestive: same `mov 0x1f,al` + three `add al,al` + `cmp` + `jb` shape, same " READY." success
# string, same tail-jump to the status tick at L_000c33. Only three things differ — the stat byte
# (DS:4C agility here, DS:4B strength in cmd_W), the refusal wording, and the field written
# (DS:61 readied weapon here, DS:62 worn armour there).
#
# The requirement is therefore a FORMULA, not a per-item table: there is no requirement array
# anywhere, which is worth saying because "each armour has a strength requirement and each weapon
# an agility requirement" is usually modelled as one. It is digit*8 against a raw stat byte.
#
# CONSEQUENCE, and it is the part that bites: DS:4C is the packed-decimal byte, not the displayed
# number. Agility 40 is stored 0x40 = 64, so the ceiling at a starting agility is digit*8 < 64,
# i.e. weapons 1..7 ready and 8 (PH) and 9 (QU) refuse with AGILE ENOUGH TO WIELD. Agility 50 is
# 0x50 = 80, which admits digit 8 but not 9. Same BCD trap already documented for the damage
# formula in asm/2E3D — plugging in the decimal instead of the byte is the mistake to avoid.
#
# NOT ESTABLISHED: that this is reached from cmd_R. cmd_R's own fragment (asm/3E50) ends at the
# menu string and its choice-reader lies outside that fragment; this routine is the only thing in
# the tree that writes DS:61 with a gate, and its DS:1F input is the same staging byte cmd_W uses,
# so the pairing is strong inference rather than a traced call edge. Confirm with a breakpoint on
# 0x40D4 during a live `R`.
# provenance: static
#           entry never appears in ExecutedInstructions of any harvest; derived by
#           tools/provenance_from_traces.py. cmd_R itself is live in 3 harvests, but this gate's
#           refusal branch has not been observed.
# confidence: medium (the rule is read directly off the bytes; the caller is inferred)
# strings: " <-THOU ART NOT "; " READY."
# calls: L_000c33 (the status tick), L_0051df (str_out)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_3ed4:
L_0040d4:
        mov    0x1f,%al
L_0040d7:
        .byte 0x02,0xc0  # forced-kept: gas re-encodes 'add    %al,%al' differently
L_0040d9:
        .byte 0x02,0xc0  # forced-kept: gas re-encodes 'add    %al,%al' differently
L_0040db:
        .byte 0x02,0xc0  # forced-kept: gas re-encodes 'add    %al,%al' differently
L_0040dd:
        cmp    0x4c,%al
L_0040e1:
        jb L_004111
L_0040e3:
        call L_0051df
        db " <-THOU ART NOT ",0x8d,"AGILE ENOUGH TO WIELD!",0x00        # string
L_00410e:
        jmp L_000c33
L_004111:
        call L_0051df
        db " READY.",0x00        # string
L_00411c:
        mov    0x1f,%al
L_00411f:
        mov    %al,0x61
L_004122:
        jmp L_000c33
