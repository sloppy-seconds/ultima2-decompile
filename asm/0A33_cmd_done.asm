# cmd_done — prints CR (AL=0x0D) via char_print and falls through to the post-command tail
# name-evidence: 59 command-handler returns jump here (jmp L_000c33); body loads 0x0D and
#           tail-calls char_print
# 2026-10-28: the tail-call is not a return. There is no `ret` here -- the body ends and
#           execution falls through to asm/0A38_post_command_tail, which is what runs the
#           creature sweep and therefore one wandering-spawn attempt after every command.
#           docs/monster-spawn.md § 15.2.
# func 0A33..0A37  len 0005 B  evidence: seed+reko
# calls: L_0055f4
# provenance: live:airport (+48 other harvests), static
#           entry executed in 49 of 60 harvests; derived by tools/provenance_from_traces.py
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
cmd_done:
L_000c33:
        mov    $0xd,%al
L_000c35:
        call L_0055f4
