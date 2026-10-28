# cmd_Y yell loop, part 2 of 7 — spin until the key seam reports a key was consumed
# func 4554..4558  len 0005 B  evidence: seed+reko; role read from the bytes 2026-10-29
# provenance: `AH = 0xFF` is asm/4F4D's documented "a key was consumed" return, so `jne` back
#           to the loop head is a blocking read written as a spin. Same convention G30 relies
#           on, and a second independent consumer of it in code that has executed.
# confidence: high
# label: sub_4554 / L_004754 / L_004757 kept as they are — labels are body (AGENTS.md § 3).
sub_4554:
L_004754:
        cmp    $0xff,%ah
L_004757:
        jne L_004751
