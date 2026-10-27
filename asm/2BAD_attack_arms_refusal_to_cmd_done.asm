# attack_arms_refusal_to_cmd_done — the arms-paralysis ATTACK refusal, and where it goes
# name-evidence: reached from asm/2BA5_attack_arms_gate when [DS:26C] is non-zero; prints
#           "PARALIZED!" via asm/51DF str_out and then `jmp L_000c30`.
# THE JUMP IS THE POINT: L_000c30 is asm/0A30, the 3-byte stub that falls through to
#           asm/0A33_cmd_done and so to asm/0A38_post_command_tail - the tail every completed
#           command reaches. So the arms refusal is NOT an early return to the input poll; it is
#           a completed command, and the post-command tick fires on it.
#           Same target as asm/0A15_invalid_move_to_cmd_done (the terrain refusal, whose tick was
#           proven by forced-poke), asm/2052, asm/228A and asm/277B.
# CONSEQUENCE, and the reason this file was renamed: the engine had
#           `if (paral_arms == 0) creature_turn(...)` on the ATTACK path, which made arm paralysis
#           permanent for a player who kept trying to swing. Corroborated in the corpus without a
#           new capture: captures/spice86/fight-20261021-castle03/turns (3000 per-turn DS dumps)
#           shows DS:26C falling 6 times, every one with the food odometer UNCHANGED, and zero
#           times with food changed.
# label: kept as sub_2bad on purpose (CP3 cross-reference anchor).
# func 2BAD..2BBD  len 0011 B  evidence: seed+reko
# calls: L_000c30, L_0051df (str_out)
# strings: "PARALIZED!"
# provenance: static bytes + existing corpus, 2026-10-29. The on-screen text itself is still
#           unobserved in motion (see the correction note in asm/2BA5_attack_arms_gate.asm).
# confidence: high for the control flow (the jump target is a byte fact); the print site has never
#           been seen executing, and that is a separate claim from this one.
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_2bad:
L_002dad:
        call L_0051df
        db "PARALIZED!",0x00        # string
L_002dbb:
        jmp L_000c30
