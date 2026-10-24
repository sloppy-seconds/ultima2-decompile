# sub_353a — MIS-DECODED: this fragment and asm/353D are one four-byte instruction cut in half
# NAME DISPUTED — not of a name but of the slice, and the bytes are unambiguous.
#           The clean wave emitted `.byte 0x8a` here as a forced-keep because gas re-encoded the
#           instruction differently. The real instruction starts at runtime 353C and is four
#           bytes, file 0x373C = `8a 1e 49 00`:
#               mov 0x49,%bl        ; BL = DS:49 = the sector TENS digit
#           The wave consumed only the opcode `8a`, then asm/353D re-read the ModRM byte `1e` as
#           `push %ds` and the displacement `49 00` as `dec %cx` plus the start of the next
#           instruction. Verified directly against original/ultimaii.exe with objdump -mi8086
#           -Mintel,data16,addr16 at --adjust-vma 0x353a, which decodes 353A..3545 cleanly as
#           `mov $0x0,%bh ; mov 0x49,%bl ; mov %bx,%di ; or %di,%di ; je 3565`.
# WHY IT MATTERS: this is the DS:49 read that G14 spent a week looking for. It is the single
#           writer of the era index handed to asm/3546_time_index_message, and it was hiding in a
#           forced-keep byte rather than being absent. See that file's header for the full era
#           table.
# cannot be fixed here: the corrected instruction means changing body lines. asm/353D has now
#           been corrected under the `# body corrected:` marker (2026-10-28d) and the whole
#           binary still rebuilds byte-identically; this file's own body is already correct for
#           its declared span 353A..353C, because the instruction genuinely starts on its last
#           byte and continues into asm/353D. The forced-keep here is honest; the invented
#           mnemonics next door were the defect.
# provenance: static, re-decoded 2026-10-28d from original/ultimaii.exe file 0x373A..0x3745
# confidence: high for the corrected decode; the committed body below is known-wrong and stays
#           because the guard says so, not because it is believed
# func 353A..353C  len 0003 B  evidence: seed+reko
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_353a:
L_00373a:
        mov    $0x0,%bh
L_00373c:
        .byte 0x8a  # forced-kept: gas re-encodes 'mov    0x49,%bl' differently
