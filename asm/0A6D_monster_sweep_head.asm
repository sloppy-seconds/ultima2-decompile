# 0A6D_monster_sweep_head — start of the per-slot creature sweep (DI = 31 down to 1)
# name-evidence: `mov $0x0,%bh ; mov $0x1f,%bl ; mov %bx,%di` sets DI to the immediate
#           31 (the same `mov $0x1f` trap that caught § 11 -- it is not a read of DS:1F),
#           and asm/0AA1_monster_sweep_next walks it down with `dec %di ; jne L_000c74`.
#           Entered from asm/0A38_post_command_tail and asm/0A5F_sub_0a5f only.
# Every completed command runs this sweep once, and the sweep ends in exactly one
# wandering-spawn attempt at asm/0AA4_monster_spawn_entry. docs/monster-spawn.md § 15.2.
# The leading nop is real: it is in the bytes, and CP0's rebuild depends on it.
# label: kept as sub_0a6d on purpose (CP3 cross-reference anchor).
# func 0A6D..0A73  len 0007 B  evidence: seed+reko
# provenance: static reassembly 2026-10-28 (docs/monster-spawn.md § 15.2)
# confidence: high for the loop shape (bytes + the loop-back label is named from three
#           sites); the per-slot body is still only partly read
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_0a6d:
L_000c6d:
        nop
L_000c6e:
        mov    $0x0,%bh
L_000c70:
        mov    $0x1f,%bl
L_000c72:
        .byte 0x8b,0xfb  # forced-kept: gas re-encodes 'mov    %bx,%di' differently
