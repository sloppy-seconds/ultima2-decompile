# sub_464e — mechanical clean (bulk wave); behavior not yet reviewed
# func 464E..4656  len 0009 B  evidence: reko
# RENDERING GAP: prints 'SPELL-' at file 0x04850, but these bytes are rendered as instructions,
#           so the atlas knows the message only from the str_out calling convention. Listed in
#           disasm/str-out-rendering-gap.tsv; the fix is a body edit, which
#           engine/tests/asm_body_guard.py forbids — see disasm/defects.md.
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_464e:
L_00484e:
        .byte 0x8f,0x09,0x53,0x50  # forced-kept: gas re-encodes '(bad)' differently
L_004852:
        .byte 0x45  # forced-kept: gas re-encodes 'inc    %bp' differently
L_004853:
        .byte 0x4c  # forced-kept: gas re-encodes 'dec    %sp' differently
L_004854:
        .byte 0x4c  # forced-kept: gas re-encodes 'dec    %sp' differently
L_004855:
        .byte 0x2d,0x00  # forced-kept: gas re-encodes 'sub    $0xa000,%ax' differently
