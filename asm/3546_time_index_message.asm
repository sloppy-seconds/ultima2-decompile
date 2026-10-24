# time_index_message — turns the numeric time index in %di into the period label
#           the game prints as "ANOS: <date>".
# name-evidence: five inline strings, file 0x3752 "ANOS: 2112 A.D.", 0x3768
#           "ANOS: LEGENDS!", 0x377D "ANOS: 9,000,000 B.C.", 0x3798
#           "ANOS: 1423 B.C.", 0x37AE "ANOS: 1990 A.D."
# func 3546..3564  len 001F B  evidence: seed+reko
# dispatch (observed: the dec/je chain and each call target):
#   %di == 1 -> "ANOS: 9,000,000 B.C."  (call at file 0x377A)
#   %di == 2 -> "ANOS: 1423 B.C."       (call at file 0x3795)
#   %di == 3 -> "ANOS: 1990 A.D."       (call at file 0x37AB)
#   %di == 4 -> falls through to the call at file 0x374F: "ANOS: 2112 A.D."
#   "ANOS: LEGENDS!" is at file 0x3765 (asm/3565_sub_3565.asm, a stop-trunc
#   one-byte call) and is NOT targeted by this chain; it is reached from a branch
#   before 3546, outside this range.
# notes: "ANOS" is the literal text, not a truncation - the byte before it is the
#        high half of the preceding call operand (0x1A), so the string begins at
#        the A. Whether it is intended as pseudo-Latin for "year" is not provable
#        from bytes.
#        The entry label still reads set_year_2112, which is now a poor name for a
#        five-way dispatch. It is left alone on purpose: the CP0 guard freezes asm
#        body content, and a label emits no bytes, so renaming it buys nothing and
#        breaks the guard. Naming lives in the filename and this header.
# calls: L_000c33 (return to command loop), L_0051df (str_out)
# apple2-twin: $777B in ULTIMA.II.OBJ, and it is the same dispatch, not a similar one. Hand-
#           decoded: `LDX $4E13` then `BEQ / DEX / BEQ / DEX / BEQ / DEX / BEQ`, five arms, each
#           a `JSR $4006` followed by its inline era string, and the fall-through (index >= 4)
#           prints 2112 A.D. — exactly this file's `dec %di ; je` chain with 2112 as the
#           fall-through. The order matches too: 0 LEGENDS, 1 9,000,000 B.C., 2 1423 B.C.,
#           3 1990 A.D., 4+ 2112 A.D. CORROBORATED, and it settles the part of G14 that
#           mattered: the five-way era split is original 1983 design, not a DOS-port invention.
#           What the Apple side adds is the SHAPE of the answer. $4E13 has exactly ONE writer
#           in the whole resident image, at $6BF8, and it is computed: `LDA $4E38 ; LSR A ;
#           CMP $4E13 ; BCC keep ; CLC ; ADC #$01 ; STA $4E13`. A value shifted right by one,
#           then plus one. That is the arithmetic that turns ten things into five — and $4E13
#           sits one byte below $4E14, which asm/2199 pins to DS:4A, the sector ONES digit.
#           tools/u2_edit.py records DS:49/4A as the sector's two decimal digits patched into
#           the mapx filename, so DS:49 is the TENS digit, and the mapping the ticket guessed
#           is the mapping the ancestor implements: tens 0-9, >>1, into five eras.
#           GRADE: inferred, and specifically NOT observed — nobody has dumped DS:49 next to the
#           value in %di at this entry. But it is inferred from two independent sides agreeing
#           on adjacency, on the shift, and on five-against-ten, which is a long way from a
#           guess. The DOS writer of the index is still unidentified: the reads of DS:49 that do
#           exist (asm/2290, 22D5, 2305, 26B7, 26CC, 2708, 3C2E_cmd_O; written by asm/26C6) are
#           filename and sector-loading sites, not this one.
# provenance: static
#           entry never appears in ExecutedInstructions of any of the 60 harvests; derived by tools/provenance_from_traces.py
# confidence: medium (strings and dispatch proven by bytes; the code that
#           initialises %di is not identified, and no static caller of 3546 was
#           found, so the index's source is inferred, not observed)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
set_year_2112:
L_003746:
        dec    %di
L_003747:
        je L_00377a
L_003749:
        dec    %di
L_00374a:
        je L_003795
L_00374c:
        dec    %di
L_00374d:
        je L_0037ab
L_00374f:
        call L_0051df
        db "ANOS: 2112 A.D.",0x00        # string
L_003762:
        jmp L_000c33
