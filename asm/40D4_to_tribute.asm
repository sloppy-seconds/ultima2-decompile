# to_tribute — the one-instruction edge from the TRANSACT type chain into the tribute
# name-evidence: `jmp L_004449`, reached only when asm/40CB has just matched creature type 0x6c.
#           Three bytes, and they are the whole reason the tribute was invisible for so long: the
#           edge is an unconditional jmp out of the cmd_T flow into a routine 0x175 bytes away
#           whose only prior name was a guess about a cleric.
# func 40D4..40D6  len 0003 B  evidence: seed+reko; role read from the bytes 2026-10-29
# calls: L_004449
# provenance: live:lord-british-tribute, static
# confidence: high
# label: sub_40d4 / L_0042d4 kept as they are — labels are body (AGENTS.md § 3).
sub_40d4:
L_0042d4:
        jmp L_004449
