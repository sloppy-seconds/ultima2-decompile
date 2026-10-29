# tribute_welcome — entry to the gold-for-HP tribute, reached by TRANSACTing at a type-0x6C creature
# name-evidence: the string 'WELCOME MY CHILD ', and the caller chain now that it is known:
#           asm/4050 cmd_T -> asm/40C0 (role < 0x80) -> asm/40CB ([slot+0x197] == 0x6c)
#           -> asm/40D4 -> here. So this is the NON-talking arm of the TRANSACT cursor split,
#           which is why it was reachable without a tlkx loader while the talking arm was not.
# func 4249..425E  len 0016 B  evidence: seed+reko
# strings: "WELCOME MY CHILD "
# calls: L_0051df (str_out)
# provenance: live:lord-british-tribute, static
#           CORRECTION 2026-10-29. This header said the entry "never appears in
#           ExecutedInstructions of any of the 60 harvests", and it has now been seen executing
#           54 times in one session (captures/spice86/lord-british-tribute). The claim was
#           true when written and then went stale; the harvest count in it was a hand-maintained
#           number, which is exactly why AGENTS.md § 3 says to read provenance from
#           tools/cmd_handlers.py rather than recall it.
# confidence: high (bytes proven by check_func.py; the whole span executed and the frame is on record)
# notes: the room drawn around this creature is headed LORD BRITISH on screen. The string LORD
#           BRITISH exists in the binary only inside the two title-screen copyright lines, and
#           the space-separated on-screen form is not in the binary at all, so the header is
#           rendered by the room code and is not creature data. Do not read the room label as
#           evidence about the type.
# label: cleric_welcome kept as it is — labels are body (AGENTS.md § 3). The name "cleric" was
#           an inference from the religious register of the greeting and is not supported.
cleric_welcome:
L_004449:
        nop
L_00444a:
        call L_0051df
        db "WELCOME MY CHILD ",0x00        # string
