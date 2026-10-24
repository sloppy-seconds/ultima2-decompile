# sub_353d — MIS-DECODED: the tail of the instruction that starts in asm/353A, not a routine
# body corrected: 2026-10-28d -- evidence: original/ultimaii.exe file 0x373D..0x3745 is
#           `1e 49 00 8b fb 0b ff 74 1f`, which objdump -mi8086 decodes from the real
#           boundary at 353A as the tail of `mov 0x49,%bl` then `mov %bx,%di ; or %di,%di ;
#           je 3565`. The four mnemonics this file used to show (push %ds, dec %cx,
#           add %cl,0xbfb(%bp,%di), push 0x1f(%si)) were the leftover bytes of an
#           instruction the clean wave abandoned after its opcode. tools/forced_keep_audit.py
#           flags asm/353A @353C as the cause; both cases are its --selftest controls.
# NAME DISPUTED — same defect as asm/353A, recorded here because this is where the wrong bytes
#           are most visible. The listing reads:
#               push %ds                      ; actually ModRM byte 0x1e of `mov 0x49,%bl`
#               dec %cx                       ; actually displacement byte 0x49
#               add %cl,0xbfb(%bp,%di)        ; actually displacement 0x00 + the next real insns
#               push 0x1f(%si)                ; likewise
#           None of it is code. The four bytes 8a 1e 49 00 at runtime 353C..353F are one
#           instruction, `mov 0x49,%bl`, loading the sector tens digit. What follows at runtime
#           3540 is real and decodes cleanly as `mov %bx,%di ; or %di,%di ; je 3565`.
# the tell: a `push %ds` immediately followed by `dec %cx` and a three-displacement `add` with no
#           matching pop is not a shape any compiler or hand-coder produces, and the ModRM byte of
#           the preceding forced-keep explains every byte in it. A forced-keep followed by an
#           implausible instruction stream should be read as ONE instruction whose decoding was
#           abandoned, not as two facts.
# cannot be fixed here: body lines are frozen by engine/tests/asm_body_guard.py and CP0. Correct
#           decode is in prose here, in asm/353A, and in disasm/defects.md.
# provenance: static, re-decoded 2026-10-28d from original/ultimaii.exe file 0x373D..0x3745
# confidence: high that the committed body is wrong; high in the replacement
# func 353D..3545  len 0009 B  evidence: reko
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_353d:
L_00373d:
        .byte 0x1e, 0x49, 0x00  # tail of `mov 0x49,%bl`; its opcode 0x8a is asm/353A's forced-keep
        .byte 0x8b, 0xfb        # mov %bx,%di -- gas encodes the same move as 89 df, so kept as bytes
        .byte 0x0b, 0xff        # or %di,%di  -- gas encodes the same or as 09 ff
        je L_003765             # 74 1f: sector tens digit 0 -> "ANOS: LEGENDS!"
