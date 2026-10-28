# cmd_Y yell loop, part 1 of 7 — poll for a key; this is the loop head
# func 4551..4553  len 0003 B  evidence: seed+reko; role read from the bytes 2026-10-29
# calls: L_00514d (asm/4F4D key_poll)
# provenance: reached only by the fall-through from asm/4542 cmd_Y, and jumped back to by
#           asm/4554 and asm/4560 as the branch target L_004751. Named when the 4542..4567
#           range was read as one routine instead of seven unreviewed fragments; the owner's
#           recollection of the manual's YELL description is what sent the re-read.
# confidence: high (one call, one caller, one branch target)
# label: sub_4551 / L_004751 kept as they are — labels are body (AGENTS.md § 3).
sub_4551:
L_004751:
        call L_00514d
