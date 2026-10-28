# cmd_Y yell loop, part 3 of 7 — the Enter test that ends the yell
# func 4559..455C  len 0004 B  evidence: seed+reko; role read from the bytes 2026-10-29
# provenance: `cmp $0xd,%al` is CR, so Enter is the terminator and nothing else exits the
#           loop. This is the byte behind the owner's "type a freeform thing, with <enter>".
# confidence: high
# label: sub_4559 / L_004759 / L_004762 kept as they are — labels are body (AGENTS.md § 3).
sub_4559:
L_004759:
        cmp    $0xd,%al
L_00475b:
        je L_004762
