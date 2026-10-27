# attack_arms_gate — the ATTACK command refuses when the arms are paralysed
# name-evidence: reached from asm/2B8F_cmd_A (which prints "ATTACK--") as the first
#           gate in its fall-through chain; reads [DS:26C] — the arms counter proven
#           by asm/0EC2_combat_paralyzed_arms — and on non-zero branches to
#           asm/2BAD_attack_arms_refusal_to_cmd_done, which prints "PARALIZED!" and then
#           `jmp L_000c30` -- i.e. it does NOT return to the input poll. L_000c30 is asm/0A30,
#           which falls through to asm/0A33_cmd_done and the post-command tail, so the refusal is
#           a completed command and the status tick fires on it (corrected 2026-10-29; this header
#           used to say it "returns to the command loop without attacking", which understated it
#           and let the engine make arm paralysis permanent).
# CORRECTION 2026-10-28d: this header used to add "observed on screen as a `CMD:` line reading
#           exactly that". It was never observed on screen. `tools/cfg_printed.py
#           captures/spice86/castle-03-live` lists print sites whose `call` is confirmed in
#           ExecutedInstructions, and asm/2BAD's `PARALIZED!` appears only under `--all`, which
#           is the discovered-but-not-executed set — the exact trap AGENTS.md § 4 names, where a
#           CFG block stands in for a run that did not happen. The look-alike that IS executed
#           there is `--PARALIZED!` at runtime 2527 = asm/2527_sub_2527, a different routine in
#           a different part of the tree, still unreviewed bulk-wave output. Two messages, two
#           addresses, and only one of them has ever reached a screen.
# provenance: static. Bytes proven by tools/check_func.py; the chain (reached from asm/2B8F_cmd_A,
#           reads [DS:26C], branches to asm/2BAD) is static inference from the listing. The arms
#           counter's identity is corroborated by asm/0EC2_combat_paralyzed_arms, whose own
#           `ARMS PARALIZED!` print IS executed in captures/spice86/castle-03-live — but that is
#           the combat field effect, not this command gate.
# owner-note: the owner's recollection that arms paralysis stops you fighting while legs paralysis
#           stops you moving is what pointed here, and the bytes agree on the structure. The
#           reject message itself is still unconfirmed in motion.
# confidence: medium (bytes proven; the gate's existence is solid, its on-screen text unobserved)
# func 2BA5..2BAC  len 0008 B  evidence: seed+reko
# confidence: medium (bytes proven by check_func.py; the chain and the counter's
#           identity are what raise it above the bulk-wave default)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
# why this matters for CP5: it is the byte proof of the owner's recollection that
#        **arms paralysis stops you fighting while legs paralysis stops you moving**.
#        Legs/arms are separate counters (C1) with separate gates in separate
#        commands — this one on ATTACK, the passability routine on movement — which
#        is exactly the shape a single boolean "paralysed" flag cannot express, and
#        is what C3 means by paralysis being a rejection rather than a mode.
#        Cited in docs/phase4-state.md § CP5 (C1, C3) and docs/phase4-kickoff-cp5.md.
# gate order in the chain, for whoever implements it: site kind first (asm/2B9B
#        tests [DS:4A] against 4), then this arms gate, then the roll
#        (asm/2BD7 calls rand, asm/2BDA does `clc; rcr $1,%al; cmp 0x4c,%al; jb`,
#        i.e. hit iff (rand >> 1) < agility byte), then --HIT!!! (asm/2BEC) or
#        MISS (asm/2E09_combat_miss_msg).
sub_2ba5:
L_002da5:
        nop
L_002da6:
        mov    0x26c,%al
L_002da9:
        .byte 0x0a,0xc0  # forced-kept: gas re-encodes 'or     %al,%al' differently
L_002dab:
        je L_002dbe
