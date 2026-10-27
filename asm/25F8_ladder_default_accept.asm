# sub_25f8 — mechanical clean (bulk wave); behavior not yet reviewed
# func 25F8..25FE  len 0007 B  evidence: seed+reko
# calls: L_0027ff, L_002804
# provenance: static (bytes) + live — the accept path this file is on is what every
#           accepted on-foot step in the corpus took (F11's walks, live:stepcost), and the
#           reject trampoline at L_0027fb/L_0027ff is the one asm/2542 sends the rocket to.
#           The two roles being in one file is the reason this address was mislabelled once
#           already; see the note below.
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
# RENAMED 2026-10-29 from sub_25f8, with the behaviour. This is the FOOT LADDER's default
#           ACCEPT, not a vehicle arm. asm/25F4 ends with `cmp $0x16,%al ; jae L_0027ff`
#           and falls through into `jmp L_002804` here, which is the accept path (asm/2664:
#           mask both coordinates with and 0x3F, return 0).
#
#           The second and third instructions are the REJECT trampoline the rocket arm
#           (asm/2542) jumps into: L_0027fb is `call L_0027ff ; ret` and L_0027ff is `mov
#           $0xff,%al ; ret`. One file, both verdicts, which is exactly how this address got
#           described as 'the rocket accepts everything' — the label was read, the callers
#           were not. See asm/2542_mode_arm_rocket.asm.
sub_25f8:
L_0027f8:
        jmp L_002804
L_0027fa:
        nop
L_0027fb:
        call L_0027ff
L_0027fe:
        ret
