# sub_0a83 — sweep gate, the mounted clause. Reached only when the player is on a horse
#           (DS:13 == 0x22, from asm/0A7C). If DS:26 >= 0 the creature gets its turn; if
#           DS:26 is negative, only mon_type 0x48 (frigate), 0x3C (balron) and 0x2C (sea
#           monster) do — everyone else is skipped for this sweep and the loop moves on.
#           The three exemptions are the same three species asm/21A6/asm/21AE single out in
#           asm/2199_creature_step_gate, which is the strongest hint in this tree that the
#           0x2C/0x48 pair is a water-dwelling class rather than two arbitrary ids.
# NOT ESTABLISHED: what DS:26's sign means here. In the overworld it was measured flipping
#           00 <-> FF on accepted movement (docs/passability-findings.md F12) and in a tower
#           it is the torch counter (docs/sector-rulesets.md § 1b), and those are probably
#           not the same byte's meaning. Do not model this clause without watching it.
# func 0A83..0AA0  len 001E B  evidence: seed+reko
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_0a83:
L_000c83:
        mov    0x26,%al
L_000c86:
        .byte 0x0a,0xc0  # forced-kept: gas re-encodes 'or     %al,%al' differently
L_000c88:
        jns L_000ca7
L_000c8a:
        mov    0x197(%di),%al
L_000c8e:
        cmp    $0x48,%al
L_000c90:
        je L_000ca7
L_000c92:
        cmp    $0x3c,%al
L_000c94:
        je L_000ca7
L_000c96:
        cmp    $0x2c,%al
L_000c98:
        je L_000ca7
L_000c9a:
        mov    0x13,%al
L_000c9d:
        cmp    $0x22,%al
L_000c9f:
        jne L_000ca7
