# cmd_Y yell loop, part 5 of 7 — back to the poll for the next character
# func 4560..4561  len 0002 B  evidence: seed+reko; role read from the bytes 2026-10-29
# provenance: unconditional `jmp L_004751`, the loop head. Together with asm/4559 this is why
#           letters typed after Y never reach the command dispatcher — the 2026-10-25 capture
#           logged that as the loop failing to return to the prompt, and it was this loop
#           working. Gate: engine/tests/cmd_yell.py, the swallow case.
# confidence: high
# label: sub_4560 / L_004760 kept as they are — labels are body (AGENTS.md § 3).
sub_4560:
L_004760:
        jmp L_004751
