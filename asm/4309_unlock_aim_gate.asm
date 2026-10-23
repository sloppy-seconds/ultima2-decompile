# 4309_unlock_aim_gate — UNLOCK only ever aims sideways, and this is why
# name-evidence: `mov 0x19,%al ; or %al,%al ; jne L_004526` — the unlock proceeds only
#           when DS:19 is non-zero, and DS:19 is the movement delta's X component
#           (asm/0B0F, and the same pair asm/4085 steps the talk ray by). Fall through
#           and it is asm/4310 "NO DOOR THERE!".
# WHY IT MATTERS: asm/4326 then computes the target as (x + DS:19, y) with no Y delta
#           anywhere in the chain. So UNLOCK is structurally horizontal-only: a north or
#           south aim cannot reach a door at all, whatever the prompt appears to accept.
#           This is the reason three live unlock attempts in docs/needs-gameplay.md G30
#           refused — the recipe aimed with an arrow in any direction and never got as
#           far as the door test.
# NOT ESTABLISHED: whether DS:19 is set by the direction key at the prompt or only by the
#           preceding move. If only by the move, the working recipe is: step east (or
#           west), then press U with no direction key at all.
# label: kept as sub_4309 on purpose (CP3 cross-reference anchor).
# func 4309..430F  len 0007 B  evidence: seed+reko
# provenance: static reassembly 2026-10-28, against the g30/g30b/g30c refusals
# confidence: high for the gate and the missing Y term; low for how DS:19 gets set
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_4309:
L_004509:
        mov    0x19,%al
L_00450c:
        .byte 0x0a,0xc0  # forced-kept: gas re-encodes 'or     %al,%al' differently
L_00450e:
        jne L_004526
