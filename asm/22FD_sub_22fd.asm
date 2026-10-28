# sub_22fd — tests DS:6D (the world byte) and branches; NOT a sector store (2026-10-29)
# name-evidence: the body is `mov 0x6d,%al ; or %al,%al ; je ..` -- read DS:6D, test it, branch.
#           There is no file I/O, no DOS interrupt, no sector arithmetic in the seven bytes.
#           DS:6D is the WORLD byte (0 Earth, 1..9 the planets, 0x0A deep space -- see
#           asm/3DFA_offer_only_outdoors_earth and asm/7030_space_collision, which writes
#           it). This routine sits on the save path: asm/3DFA calls it at 404A after its own
#           DS:6D guard, so it is a second look at the same test, not a store.
# NAMING HISTORY: an earlier revision of this header called it a boots/paralysis gate, because
#           state.h called the byte boots_count. That name was our own tool's invention; the
#           byte never was boots.
# WHY THIS MATTERS: engine/src/game/overworld.c carried the comment "asm/22FD stores the
#           sector being left" and implemented site_enter() and site_leave() as writes back
#           to mapxNN and monxNN on every transition. That attribution is refuted twice
#           over: the routine does not resemble a store, and the original provably writes no
#           sector file at all (2026-10-29 live session -- mapx31, monx31, mapx30 and monx30
#           in the run dir are byte-identical to the pristine copies after several town
#           entries and exits; only `player` is written). The engine's store-on-transition
#           is therefore not a reconstruction of anything, and it has already damaged a game
#           file: original/monx71 was found rewritten (mtime 2026-10-23, monster coords and
#           HP drifted) and has been restored from references/. See docs/phase4-state.md.
# confidence: high for what the bytes are: a world test on the save path
# func 22FD..2303  len 0007 B  evidence: seed+call+reko
# provenance: re-read 2026-10-29 against the noVNC persistence session; previously an
#           unreviewed bulk-wave stub whose address was being cited as a sector store
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_22fd:
L_0024fd:
        mov    0x6d,%al
L_002500:
        .byte 0x0a,0xc0  # forced-kept: gas re-encodes 'or     %al,%al' differently
L_002502:
        je L_002505
