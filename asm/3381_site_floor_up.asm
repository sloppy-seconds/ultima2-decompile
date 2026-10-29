# site_floor_up — the increment arm of the floor pair, and the arm with no bound check
# name-evidence: the target of `jmp L_003581` from asm/334D cmd_D when the site kind is 5 (going
#           deeper in a dungeon) and from asm/3812 cmd_K's gate when the kind is 4 (climbing in a
#           tower). Three instructions: `nop`, `incb 0x25`, `jmp L_003a2a` — the jump lands past
#           the `decb`/`js` in asm/3823, so this arm prints the level and can never exit.
# func 3381..3388  len 0008 B  evidence: reko; role read from the bytes 2026-10-29
# calls: L_003a2a
# provenance: static bytes; the pair's shape is corroborated by the UP LADDER and DOWN LADDER
#           spell arms in asm/3139, which took [DS:25] 0 -> 1 -> 0 in the sector-24 tower
# confidence: high
# notes: the absence of a bound check is the interesting fact, not an oversight to fix. Climbing
#           above a tower's top increments past it and prints the result; asm/1451 separately
#           bounds the byte with `cmp $0xf`, so the grid index and the counter disagree about
#           what the ceiling is. Recorded, not reconciled.
# label: sub_3381 / L_003581 kept as they are — labels are body (AGENTS.md § 3).
sub_3381:
L_003581:
        nop
L_003582:
        incb   0x25
L_003586:
        jmp L_003a2a
