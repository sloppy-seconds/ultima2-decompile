# tribute_raise — announces the raise; the amount comes from the ladder in asm/42AA..42CB
# name-evidence: the string 'AND FOR IT I RAISE THEE '. Reached by fall-through from the paid
#           tribute in asm/4262, and what follows it is a four-rung comparison on [DS:51] — the
#           HIGH packed-decimal byte of HP — so the raise is in hundreds and the low two digits
#           never move. asm/53a5 prints the rung value after this string.
# func 428E..42A9  len 001C B  evidence: seed+reko
# strings: "AND FOR IT I RAISE THEE "
# calls: L_0051df (str_out)
# provenance: live:lord-british-tribute, static
#           CORRECTION 2026-10-29: "never appears in ExecutedInstructions" is retired. All four
#           rungs fired in one session — +300 up to HP 5101, +200 to 7501, +100 to 9901, +0 above.
#           The frame reads `AND FOR IT I RAISE THEE @300`.
# confidence: high
# notes: the +0 rung is an OVERFLOW GUARD, not stinginess. At high byte 0x99 a further +100 would
#           carry past a packed-decimal byte, so the cmp $0x99 rung is what stops HP ever
#           exceeding 9999. It reads as the game being mean and it is the game being correct.
# label: cleric_raise kept as it is — labels are body (AGENTS.md § 3). "Raises the dead" was the
#           old gloss and is wrong: it raises hit points, and the patient is alive.
cleric_raise:
L_00448e:
        call L_0051df
        db "AND FOR IT I RAISE THEE ",0x00        # string
