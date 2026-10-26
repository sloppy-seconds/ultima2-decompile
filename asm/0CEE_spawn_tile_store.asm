# 0CEE_spawn_tile_store — store the terrain tile into the slot, then a bit-test dispatch on DS:60
# RENAMED 2026-10-28 from 0CEE_monster_kind_store, owner-approved. The old name claimed the
#   stored byte was a monster kind; it is the terrain tile of the rolled spawn coordinate,
#   returned by asm/50B3_map_tile_ptr one instruction earlier. Filename and header only —
#   sub_0cee and every L_ label are body and were not touched (CP0).
# After the tile store: `incb [0x60]` then a chain of `clc ; rcr al,1 ; jae …`, each bit
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
#           CORROBORATED 2026-10-26 by a direct rate measurement, and it disposes of a "spawns
#           should be off-screen" report at the same time. 100 arrow commands on the world map in
#           sector 00 produced ZERO 0 -> non-zero mon_type transitions, because sector 00 ships
#           31 of 32 slots occupied and slot 0 is unreachable to the scan (`dec di ; jne` stops at
#           1) — so the spawner is structurally unable to fire until a creature dies. Counting the
#           shipped data: 16 of 33 sectors have no free slot in 1..31 at all. The consequence is
#           that killing a creature is precisely what opens the gate, which is why a spawn landing
#           a turn after a kill is the original's mechanism and not a divergence. There is no
#           viewport or distance test anywhere in the cluster: asm/0CB6..0CD4 rolls two bytes,
#           masks to 0x3F, and the only placement constraints are a free slot and the rolled cell's
#           terrain matching the arm's want_tile. Note also that death clears hp, type and kind but
#           NOT x/y, so a freed slot keeps the dead creature's coordinates until the next roll
#           overwrites them — the one mechanism that could have made a spawn appear on the corpse,
#           and it does not survive the store at asm/0CC0.
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
# RENAMED 2026-10-28 from 0CEE_monster_kind_store, owner-approved. The old name claimed the
#   stored byte was a monster kind; it is the terrain tile of the rolled spawn coordinate,
#   returned by asm/50B3_map_tile_ptr one instruction earlier. Filename and header only —
#   sub_0cee and every L_ label are body and were not touched (CP0).
# WHAT THE STORED BYTE IS: the return of asm/50B3_map_tile_ptr, called one instruction
#   earlier at runtime 0CEB — the terrain tile of the cell the coordinate roll picked, staged
#   through DS:23/DS:24. Not a monster kind, not a sprite. Confirmed two ways:
#   11/11 observed spawns carry the mapx20 byte of their own slot coordinates, and the two
#   arms that compare against 0x00 are the two sea creatures. Proposed rename
#   0CEE_spawn_tile_store; left alone pending an owner call, since the name is discovered
#   rather than mechanical. docs/monster-spawn.md section 15.4.
# DS:60 MEANING, settled 2026-10-28 by forcing it: it is the selector input, and the arm the
#   chain takes is the one belonging to the LOWEST set bit of its value after this incb, with
#   a zero byte falling through to the Balron arm. Pinned at runtime for all nine arms by
#   poking DS:60 = N-1 and trapping the arm entries; the discriminating case is chain value
#   0x12, where bits 1 and 4 are both set and the Thief arm runs, not the Fighter arm.
# provenance: static reassembly 2026-10-23, live-disproved same day, re-lived 2026-10-28,
#           selector pinned by forced-value capture 2026-10-28 (runs sel-pin, sel-pin2)
# confidence: high for the bytes, the dispatch shape, the reachability and what DS:60 means
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
