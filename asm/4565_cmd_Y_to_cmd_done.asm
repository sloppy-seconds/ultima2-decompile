# cmd_Y yell loop, part 7 of 7 — return to the command dispatcher
# func 4565..4567  len 0003 B  evidence: seed+reko; role read from the bytes 2026-10-29
# calls: L_000c33 (cmd_done — the same target asm/37DC cmd_J jumps to directly)
# provenance: this is the fragment that settled the question the 2026-10-25 capture left open.
#           The yell does reach cmd_done; it just cannot until Enter is pressed, which is why
#           a scripted run that never sends CR sees no prompt resume. Gate: cmd_yell.py.
# confidence: high
# label: sub_4565 / L_004765 kept as they are — labels are body (AGENTS.md § 3).
sub_4565:
L_004765:
        jmp L_000c33
