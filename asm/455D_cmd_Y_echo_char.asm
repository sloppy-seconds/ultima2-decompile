# cmd_Y yell loop, part 4 of 7 — echo the typed character
# func 455D..455F  len 0003 B  evidence: seed+reko; role read from the bytes 2026-10-29
# calls: L_0055f4 (asm/53F4 char_print_wrap — wraps at 80 columns)
# provenance: the echo is the whole effect of the command. No store anywhere in 4542..4567,
#           which is what makes the yell display-only rather than merely invisible.
# confidence: high
# label: sub_455d / L_00475d kept as they are — labels are body (AGENTS.md § 3).
sub_455d:
L_00475d:
        call L_0055f4
