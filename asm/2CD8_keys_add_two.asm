# keys_add_two — add 2 to the key count in packed decimal
# name-evidence: bytes, whole function read (observed). Body is
#           `clc; mov 0x65,%al; adc $0x2,%al; daa; mov %al,0x65; jmp L_002f8c`.
#           DS:65 is the key count, one packed-decimal byte, per
#           docs/save-format.md ("0x64/0x65/0x66 torches/keys/tools, BCD, one
#           byte each", proven). Renamed from sub_2cd8 on 2026-10-22 by the
#           decimal census (tools/bcd_census.py). The GAME ACTION that reaches
#           this is not proven: no `call L_002ed8` exists anywhere in asm/, so it
#           is entered indirectly (jump table or an unsplit region). Named for the
#           arithmetic only, per "a wrong name is worse than no name".
# label: kept as `sub_2cd8` on purpose. CP0 (engine/tests/run_cp0.sh) pins every
#           non-comment line across a rename, so only the filename and the header
#           may carry a discovered name. Do not "tidy" the label to match.
# func 2CD8..2CE4  len 000D B  evidence: seed+reko
# calls: L_002f8c
# provenance: static:tools/bcd_census.py
# confidence: high for the arithmetic (13-byte whole function, no clamp anywhere,
#           so the count wraps 99 -> 00 at the ceiling); low for the caller.
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_2cd8:
L_002ed8:
        clc
L_002ed9:
        mov    0x65,%al
L_002edc:
        adc    $0x2,%al
L_002ede:
        daa
L_002edf:
        mov    %al,0x65
L_002ee2:
        jmp L_002f8c
