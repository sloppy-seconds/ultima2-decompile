# tools_add_one — add 1 to the tool count in packed decimal
# name-evidence: bytes, whole function read (observed). Body is
#           `clc; mov 0x66,%al; adc $0x1,%al; daa; mov %al,0x66`. DS:66 is the
#           tool count, one packed-decimal byte, per docs/save-format.md
#           (proven). Renamed from sub_2cf6 on 2026-10-22 by tools/bcd_census.py.
#           No `call L_002ef6` exists in asm/, so entry is indirect and the game
#           action is unproven; named for the arithmetic only.
# label: kept as `sub_2cf6` on purpose. CP0 (engine/tests/run_cp0.sh) pins every
#           non-comment line across a rename, so only the filename and the header
#           may carry a discovered name. Do not "tidy" the label to match.
# func 2CF6..2CFF  len 000A B  evidence: seed+reko
# provenance: static:tools/bcd_census.py
# confidence: high for the arithmetic (10-byte whole function, no clamp, so the
#           count wraps at the 99 ceiling); low for the caller.
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_2cf6:
L_002ef6:
        clc
L_002ef7:
        mov    0x66,%al
L_002efa:
        adc    $0x1,%al
L_002efc:
        daa
L_002efd:
        mov    %al,0x66
