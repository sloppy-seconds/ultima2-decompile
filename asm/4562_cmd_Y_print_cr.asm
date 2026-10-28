# cmd_Y yell loop, part 6 of 7 — print the Enter that ended the yell
# func 4562..4564  len 0003 B  evidence: seed+reko; role read from the bytes 2026-10-29
# calls: L_0055f4 (asm/53F4 char_print_wrap)
# provenance: reached from asm/4559 with AL still holding 0x0D, so the terminator prints like
#           any other character. There is no separate newline constant here — the CR is the
#           leftover of the test, which is why the engine prints '\r' at this site.
# confidence: high
# label: sub_4562 / L_004762 kept as they are — labels are body (AGENTS.md § 3).
sub_4562:
L_004762:
        call L_0055f4
