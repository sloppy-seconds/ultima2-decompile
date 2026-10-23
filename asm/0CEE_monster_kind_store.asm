# 0CEE_monster_kind_store — store mon_kind[DI], then a bit-test dispatch on DS:60
# After the kind store: `incb [0x60]` then a chain of `clc ; rcr al,1 ; jae …`, each bit
# selecting a species branch that sets type and HP for the slot. asm/0D4F_monster_hp_orc
# is the Orc branch and writes type 0x30 with hp 0x10 = 16, matching the bestiary's Orc
# HP of 16 from an unrelated third-party source — the one cross-check in this cluster
# that holds up independently.
# REACHABILITY, established 2026-10-28: this block is inside the spawner cluster, and the
# only entry to that cluster is asm/0AA4_monster_spawn_entry, the fall-through end of the
# per-command creature sweep (which asm/0A38_post_command_tail reaches on the sector's low
# decimal digit). So one spawn *attempt* per completed command, and reaching
# this instruction additionally requires a free slot and a passing coordinate roll --
# measured DS:60 = 22 -> 23 across 80 arrow steps with all 32 mon_type slots occupied,
# i.e. the free-slot scan is what refuses, not the cadence. docs/monster-spawn.md § 15.2.
# Registers at a live stop here: DI = the slot just allocated (0x12, 0x1A seen), DS = 0x8BE,
# SS:SP = 0BCE:0100 with nothing on the stack.
# NOT ESTABLISHED, and the live check made it worse rather than better: DS:60 read 0 after
# a session in which the player moved and food fell, so the `incb` path never ran and
# "spawn counter" has no observation behind it at all. See docs/monster-spawn.md § 11.
# CORRECTION 2026-10-28: that downgrade was itself wrong. DS:60 has since been read
# advancing (09 -> 0A, and 22 -> 23) in sessions where spawns happened. But it is NOT a
# monotone spawn count: asm/0DC4_monster_hp_fighter_frigate_devil_wizard_balron.asm starts
# with `decb 0x60 ; jmp L_000daf`, and that is the shared reject tail the arms jump to when
# their `cmp` on [DI+0x1B7] does not match. So the increment here is rolled back whenever
# the arm the bit chain selected turns out to want a different kind -- DS:60 is a rotating
# selector feeding the `rcr` chain, and its value is neither "monsters spawned" nor proof
# of how many attempts ran.
# provenance: static reassembly 2026-10-23, live-disproved same day, re-lived 2026-10-28
# confidence: high for the bytes, the dispatch shape and the reachability; LOW for what
#           DS:60 means
# func 0CEE..0D05  len 0018 B  evidence: seed+reko
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_0cee:
L_000eee:
        mov    $0x0,%bh
L_000ef0:
        mov    0x1f,%bl
L_000ef4:
        .byte 0x8b,0xfb  # forced-kept: gas re-encodes 'mov    %bx,%di' differently
L_000ef6:
        mov    %al,0x1b7(%di)
L_000efa:
        incb   0x60
L_000efe:
        mov    0x60,%al
L_000f01:
        clc
L_000f02:
        rcr    $1,%al
L_000f04:
        jae L_000f09
