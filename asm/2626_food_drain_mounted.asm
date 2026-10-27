# food_drain_mounted — subtracts 19 from the food triple, and then a SECOND 19
# name-evidence: the same `cmc ; sbb $0x19,%al ; das` triple as
#           asm/2599_food_drain_walk.asm, at file 0x282c. The double charge is the
#           point: on the no-underflow path (`jb` taken) it `call`s asm/2575, whose
#           delay tail falls through into asm/2599 and subtracts 19 again. So the mode
#           that reaches THIS file pays 38 per step attempt, not 19.
#           Entered twice: by `jmp` from asm/2557_sub_2557.asm (the [DS:13]==0x22 horse
#           arm of asm/2423_passability) and by `call` from asm/2604_sub_2604.asm (the
#           [DS:13]==0x26 plane arm).
#           Measured by forcing [DS:13] on the maxed seed, sector 31, one arrow each:
#           0x22 -> 997440 -> 997402 (-38); 0x26 -> 997518 -> 997480 (-38); 0x78 foot
#           -> -19; 0x24 ship and 0x28 rocket -> 0. A delta of 38 is mod 10 == 8, which
#           no number of 10-food auto-PASSes can imitate, so the two charges are
#           separable from the idle-gap confound.
# caveat: the horse and plane values were forced with a poke to DS:13, not reached by
#           boarding. The charge path reads only DS:13 and DS:29, but a real boarding
#           sequence sets more than DS:13 and the plane's own step path may not be the
#           walk loop at all. Grade the 38 as observed-under-a-forced-byte.
#           And DS:13 is VOLATILE: the game restores it, so a poked mode can be gone by
#           the time the key is processed even though --poke read it back correctly. One
#           plane sample came in at -39 (one charge, mod 10 = 9) for exactly that reason
#           and was discarded only after a re-run that read DS:13 in the before-peek
#           alongside the food. Confirm a forced byte at the moment of the input.
# provenance: live:stepcost (tmp/20261025-213254, 2026-10-25)
# confidence: high for the double subtract, medium for which real states reach it
# func 2626..2663  len 003E B  evidence: call+reko
# calls: L_00248d, L_002775, L_002804
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
# THIS FILE IS ALSO A TILE RULE, and that half was never read until 2026-10-29. After the
#           second subtract (which happens inside `call L_002775`, the foot tail) the
#           verdict is taken here, at runtime 0x2851..0x2862:
#
#             cmp $0xff,%al ; je reject          ; the foot ladder already refused it
#             mov 0x29,%al ; and $0x7f,%al
#             cmp $0x2,%al  ; je reject          ; map 0x04 = SHALLOW WATER
#             cmp $0x60,%al ; je reject          ; the stamp divert, refused outright
#             jmp L_002804                       ; accept
#
#           So a horse and a plane walk everywhere a footman walks EXCEPT shallow water,
#           and the plane additionally refuses forest (asm/2604). 'Horse uses the same
#           ladder as foot' — the words in F14 and in the vehicle handoff — is wrong by
#           exactly this one tile, and the shallows reject is the kind of rule a per-tile
#           table would have had to be guessed into existence. The 0x60 test is redundant
#           against the ladder (0x60 >= 0x16 already rejects it) but the bytes test it
#           explicitly ahead of the divert, so the engine does too.
#           Grade: bytes. Never observed: no capture has walked a horse or a plane, so the
#           shallows refusal has no live sample and is graded inferred-from-bytes.
sub_2626:
L_002826:
        nop
L_002827:
        stc
L_002828:
        mov    0x55,%al
L_00282b:
        cmc
L_00282c:
        sbb    $0x19,%al
L_00282e:
        das
L_00282f:
        cmc
L_002830:
        mov    %al,0x55
L_002833:
        mov    0x54,%al
L_002836:
        cmc
L_002837:
        sbb    $0x0,%al
L_002839:
        das
L_00283a:
        cmc
L_00283b:
        mov    %al,0x54
L_00283e:
        mov    0x53,%al
L_002841:
        cmc
L_002842:
        sbb    $0x0,%al
L_002844:
        das
L_002845:
        cmc
L_002846:
        mov    %al,0x53
L_002849:
        jb L_00284e
L_00284b:
        jmp L_00248d
L_00284e:
        call L_002775
L_002851:
        cmp    $0xff,%al
L_002853:
        je L_0027ff
L_002855:
        mov    0x29,%al
L_002858:
        and    $0x7f,%al
L_00285a:
        cmp    $0x2,%al
L_00285c:
        je L_0027ff
L_00285e:
        cmp    $0x60,%al
L_002860:
        je L_0027ff
L_002862:
        jmp L_002804
