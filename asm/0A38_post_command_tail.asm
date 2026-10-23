# 0A38_post_command_tail — the tail every completed command falls through to
# name-evidence: reached only by fall-through from asm/0A33_cmd_done (no branch names
#           L_000c38 anywhere in the tree); clears DS:22/20/21, then `mov 0x4a,%al;
#           or %al,%al; je L_000c6d` -- the only two in-binary entries to the creature
#           sweep head are this `je` and the `jne` in asm/0A5F_sub_0a5f.asm.
# This is the answer to "what triggers a wandering spawn": not a step and not a clock
# tick, but the end of a command. See docs/monster-spawn.md § 15.2.
# NOT ESTABLISHED: what DS:4A is. It is the gate -- measured 0 in a live sector-20
#           overworld session, so the sweep was running there, but 0's meaning is unknown.
# label: kept as sub_0a38 on purpose (CP3 cross-reference anchor).
# func 0A38..0A49  len 0012 B  evidence: seed+reko
# provenance: static reassembly 2026-10-28 (docs/monster-spawn.md § 15.2), corroborated
#           by a stop at 17D:0CEE reached during an arrow-key walk in the same session
# confidence: high for the flow and the gate byte's behaviour; none for DS:4A's meaning
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_0a38:
L_000c38:
        mov    $0x0,%al
L_000c3a:
        mov    %al,0x22
L_000c3d:
        mov    %al,0x20
L_000c40:
        mov    %al,0x21
L_000c43:
        mov    0x4a,%al
L_000c46:
        .byte 0x0a,0xc0  # forced-kept: gas re-encodes 'or     %al,%al' differently
L_000c48:
        je L_000c6d
