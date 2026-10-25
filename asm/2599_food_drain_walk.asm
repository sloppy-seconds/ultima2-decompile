# food_drain_walk — subtracts 19, packed decimal, from the food triple DS:53/54/55
# name-evidence: the subtract itself — `cmc ; sbb $0x19,%al ; das` on DS:55, borrow
#           propagated through DS:54 then DS:53, the same idiom as the 10-food PASS
#           drain at asm/090D_sub_090d.asm.
#           Entry is by fall-through, not by call: nothing references this label. The
#           delay tail at asm/2575 runs into it, and that tail is reached from
#           asm/2553_sub_2553.asm when [DS:13] is not 0x22/0x24/0x26/0x28 — i.e. on
#           foot (0x78) — and by `call` from asm/2626_food_drain_mounted.
#           ORDER IS THE FINDING: the subtract sits BEFORE the accept/reject verdict.
#           The tile compares are downstream at asm/25C0, after the `jb`. So a step
#           that ends in `--INVALID MOVE!` pays the food anyway. Settled live on the
#           maxed seed in sector 31: one Left arrow into the blocked cell (49,25) left
#           DS:00/01 unchanged and took exactly 19 (997904 -> 997885) with
#           `CMD: WEST--INVALID MOVE!` on screen; one Down arrow into an open cell
#           moved and took exactly 19. Auto-PASS is a separate 10 (asm/090D), which is
#           why delta mod 10 == 9 is the signature of exactly one step charge however
#           many passes fired in between — the measurement technique that survives the
#           idle-gap confound.
#           This refutes CP4b T2's "the walk loop calls no food drain": asm/0965,
#           asm/098C, asm/09B2 and asm/09D8 each `call 0x2423`, and this is inside it.
# underflow: `jb` taken = no borrow = food survived. The fall-through `jmp 0x248d` is
#           the starvation tail, same shape as asm/090D's.
# provenance: live:stepcost (tmp/20261025-213254, 2026-10-25) + the asm/2423 call graph
# confidence: high
# func 2599..25BC  len 0024 B  evidence: seed+reko
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_2599:
L_002799:
        stc
L_00279a:
        mov    0x55,%al
L_00279d:
        cmc
L_00279e:
        sbb    $0x19,%al
L_0027a0:
        das
L_0027a1:
        cmc
L_0027a2:
        mov    %al,0x55
L_0027a5:
        mov    0x54,%al
L_0027a8:
        cmc
L_0027a9:
        sbb    $0x0,%al
L_0027ab:
        das
L_0027ac:
        cmc
L_0027ad:
        mov    %al,0x54
L_0027b0:
        mov    0x53,%al
L_0027b3:
        cmc
L_0027b4:
        sbb    $0x0,%al
L_0027b6:
        das
L_0027b7:
        cmc
L_0027b8:
        mov    %al,0x53
L_0027bb:
        jb L_0027c0
