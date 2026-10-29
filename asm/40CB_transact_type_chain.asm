# transact_type_chain — the creature-type arm of the TRANSACT cursor split, where 0x6C is the tribute
# name-evidence: reached from asm/40C0 when [slot+0x1D7] is BELOW 0x80, i.e. the slot has no
#           scripted tlkx line. It reads [slot+0x197] (the creature type) and compares against
#           0x6c; a match jumps to asm/40D4 and thence to the tribute at asm/4249. The next test,
#           0x60, is the guard chain.
# func 40CB..40D3  len 0009 B  evidence: seed+reko; role read from the bytes 2026-10-29
# provenance: live:lord-british-tribute, static
# confidence: high
# notes: this is the reason the tribute needed no tlkx loader. The split at asm/40C0 is
#           scripted-versus-typed, and the tribute lives on the typed side, so it was reachable
#           while the talking branch was blocked. Type 0x6C occurs four times in three sectors
#           (23 slot 8, 33 slot 8, 93 slots 10 and 11), all castle-kind; the 93/11 instance
#           carries role 0x84 and is unresolved.
# label: sub_40cb / L_0042cb kept as they are — labels are body (AGENTS.md § 3).
sub_40cb:
L_0042cb:
        nop
L_0042cc:
        mov    0x197(%di),%al
L_0042d0:
        cmp    $0x6c,%al
L_0042d2:
        jne L_0042d7
