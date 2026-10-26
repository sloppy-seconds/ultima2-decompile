# creature_wander_step — role >= 3: stage this slot's per-slot step vector, then roll
# name-evidence: reached from the role dispatch at asm/1035 (`al >= 3 -> L_001286`), and its body
#           loads DS:19/DS:1A — the step vector, the same pair asm/0AFC says `call L_005111`
#           overwrites with the unit step — from two per-slot arrays indexed by DS:25: DS:1F7 for x
#           and DS:217 for y. It does NOT compute anything toward the player, which is what makes it
#           a wander and not a pursuit. `L_005417` is rand_byte (established by
#           asm/0B62_melee_hit_roll and asm/0AAA_combat_special_attack_gate).
# PROVEN (measured, 2026-10-26, captures/spice86/linda-thief and linda-aggro):
#           * DS:1F7 and DS:217 hold ONLY 0x00, 0x01 and 0xFF live — signed unit steps in {-1,0,+1}.
#             Read from two independent memory dumps, and peeked live at DS:1F7/DS:217.
#           * They are non-zero ONLY in role-3 slots. In sector 22 slots 0..15 (roles 0, 2, 0x81..0x84)
#             are all zero; slots 16..31 (all role 03) carry the vectors.
#           * `monx22` ships ZEROS at file offsets 192 and 224, which map to DS:1F7/DS:217 under the
#             established monx[0] -> DS:137 mapping (192 + 0x137 = 0x1F7). So the vectors are written
#             at runtime, not loaded from the sector file.
#           * Role-3 creatures DO move. Thief slot 20 in sector 22 was seen at (7,47), (7,49) and
#             (8,48) across PASS commands, i.e. its direction changed during play. This is what
#             refutes the engine's `moves = (role == 1 || role == 2)`, which freezes them.
# NOT ESTABLISHED — do not read this header as claiming these:
#           * WHO writes DS:1F7/DS:217, or how often. The re-randomisation is inferred from a tracked
#             creature changing direction; no writer has been found. docs/handoff-2026-10-24.md
#             suggested "per-slot persistent direction" and that word *persistent* is now doubtful.
#           * WHAT the rand_byte result is used for. It is the last instruction in this span and its
#             consumer is not identified.
#           * Whether this span performs the move at all. It only stages DS:19/1A; the move routine is
#             NOT called here (contrast asm/1039's role-2 path, which does `call asm/4F11` and jumps to
#             the move at asm/2122). Whoever implements role 3 must find where the staged vector is
#             actually consumed.
#           * The identity of DS:25, still `reserved_25` in state.h. It indexes the arrays, so it is
#             almost certainly the slot index, but that is inference from usage.
# NOTE on the dispatch: asm/1035 tests `al >= 3`, not `== 3`. The engine has `if (role > 3) continue`,
#           which differs. It is currently harmless: a census of all 33 shipped monx files gives
#           role 0x00 x686, 0x01 x54, 0x02 x75, 0x03 x179, 0x81..0x85 x62, and NO role > 3 anywhere.
#           If a sector ever ships one, the engine will freeze what the original wanders.
# provenance: live:linda-thief, live:linda-aggro (2026-10-26) + static reassembly
# confidence: high for the vector semantics and for role 3 moving; low for the writer, the roll's
#           consumer, and where the move happens
# func 1086..109F  len 001A B  evidence: seed+reko
# calls: L_005417
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
# label: kept as sub_1086 on purpose — labels are body (CP0)
sub_1086:
L_001286:
        nop
L_001287:
        mov    $0x0,%bh
L_001289:
        mov    0x25,%bl
L_00128d:
        .byte 0x8b,0xfb  # forced-kept: gas re-encodes 'mov    %bx,%di' differently
L_00128f:
        mov    0x1f7(%di),%al
L_001293:
        mov    %al,0x19
L_001296:
        mov    0x217(%di),%al
L_00129a:
        mov    %al,0x1a
L_00129d:
        call L_005417
