# combat_magic_missile — magic-missile combat spell event
# name-evidence: string 'MAGIC MISSILE!'
# func 0F12..0F47  len 0036 B  evidence: call+reko
# strings: "MAGIC MISSILE!"
# calls: L_004d26, L_0051df (str_out), L_0061c3
# provenance: live:castle-03-live — string executed in the 2026-10-21 sector-00
#           caster fight. Reached only from the dispatch at asm/0AD3.
# notes: NO item save exists on this path — unlike asm/0E70, asm/0EC2 and
#           asm/0F48 there is no inventory gate and no resist roll, so the damage
#           always applies. It accumulates into a 3-byte counter at file 0x112E:
#           [DS:20] += 2, [DS:21] += 2, then clc; [DS:22] = [DS:22] + 0x40.
#           [DS:22] was read as 0xC0 live after three casts, which is consistent
#           with +0x40 per cast. The exact BCD weight of DS:20/21/22 against the
#           HP subtract is NOT proven; do not model it as a plain integer.
# confidence: medium (dispatch, absence of a save and the accumulation bytes are
#           proven; the damage scaling is not)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
combat_magic_missile:
L_001112:
        call L_0051df
        db "MAGIC MISSILE!",0x0d,0x00        # string
L_001125:
        call L_004d26
L_001128:
        call L_0061c3
L_00112b:
        call L_004d26
L_00112e:
        incb   0x20
L_001132:
        incb   0x20
L_001136:
        incb   0x21
L_00113a:
        incb   0x21
L_00113e:
        .byte 0xf8  # forced-kept: gas re-encodes 'clc' differently
L_00113f:
        .byte 0xa0,0x22,0x00  # forced-kept: gas re-encodes 'mov    0x22,%al' differently
L_001142:
        .byte 0x14,0x40  # forced-kept: gas re-encodes 'adc    $0x40,%al' differently
L_001144:
        .byte 0xa2,0x22,0x00  # forced-kept: gas re-encodes 'mov    %al,0x22' differently
L_001147:
        .byte 0xc3  # forced-kept: gas re-encodes 'ret' differently
