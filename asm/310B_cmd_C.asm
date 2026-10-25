# cmd_C — command handler 'C' (CAST): prints "CAST-", jumps to 0x3353 when
#           key check taken, sets ES to video (0xB800) then 0xBA00 calling
#           sub_3339 between, runs a timed wait (AH=28h, CX=0x4000 via
#           sub_54ca), prints "PICXXX  ", returns to dispatcher.
# func 310B..3138  len 046 B  evidence: seed+reko (jump table cs:0730 entry C)
# provenance: live:cmd-letters2-20261025; static
#           entry executed in 2 of 141 harvests; confirmed by the capture of 2026-10-25.
#           OPEN QUESTION the capture raised rather than settled: the direction key sent after
#           `CAST-` produced `EAST--INVALID MOVE!`, which is the step-rejection path, so the
#           arrow may have been taken as movement instead of as the cast aim. Either the aim
#           gate at asm/3353 was not entered from this seed state, or the invalid-move came
#           from something else. Not established; needs a re-run with the aim read live.
#           Was recorded as never executed against a 60-harvest corpus that has since grown.
# confidence: medium (flow proven; PICXXX/delay purpose inferred)
# notes: slice mis-decoded the mov/call chain (cmp $0xb890...); bytes identical
cmd_C:
        call L_0051df          # str_out — prints the inline string below
        db "CAST-",0           # string
        jmp    L_003353
        nop
        mov    $0xb800,%ax     # video segment
        call L_003339
        mov    $0xba00,%ax     # game data segment
        call L_003339
        mov    $0x28,%ah
        mov    $0x4000,%cx
        mov    $0x0,%dx
        call L_0054ca          # timed wait
        db "PICXXX  "          # string (no NUL: continues into next fragment)
        jmp L_000c33           # return to dispatcher
