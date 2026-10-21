# combat_special_attack_gate — decides whether a monster attempts a special attack
# name-evidence: [DS:19] and [DS:1A] both tested < 3, then an L_005417 roll tested
#           < 0x20, falling through to asm/0AD3 which dispatches the four specials
# func 0AAA..0AB5  len 000C B  evidence: seed+reko
# calls: L_0052ef
# provenance: live:castle-03-live — the gate and all four callees executed during
#           the 2026-10-21 sector-00 caster fight.
# notes: three conditions, all required: [DS:19] < 3, [DS:1A] < 3, and
#           rand(L_005417) < 0x20, i.e. a 32/256 = 12.5% chance per monster turn.
#           [DS:19] and [DS:1A] are cleared to 0 by asm/24B5 when a force field
#           fires, so the two are linked: crossing a field re-arms the gate.
#           The exact meaning of the two counters is NOT proven.
# confidence: medium (thresholds proven by bytes; counter semantics inferred)
sub_0aaa:
L_000caa:
        .byte 0x8b,0xdf  # forced-kept: gas re-encodes 'mov    %di,%bx' differently
L_000cac:
        mov    %bl,0x29
L_000cb0:
        mov    0x19,%al
L_000cb3:
        call L_0052ef
