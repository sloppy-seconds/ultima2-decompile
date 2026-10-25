# sub_6cc4 — mechanical clean (bulk wave); behavior not yet reviewed
# func 6CC4..6D3D  len 007A B  evidence: call+reko
# calls: L_004daa
# confidence: low (bytes proven by check_func.py)
# body corrected: 2026-10-28e -- evidence: the first three bytes are the tail of
#           `or %ah,0x47b(%bx,%si)` (`08 a0 7b 04`) whose opcode is the forced-keep at
#           asm/6B3D; `mov 0x47b,%al` was those three bytes read as an instruction, and gas
#           encodes the `or` exactly, so the marker on 6B3D blames gas for a boundary.
#           Everything from 6CC7 was already aligned and is unchanged. Found by
#           tools/forced_keep_audit.py.
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_6cc4:
L_006ec4:
        .byte 0xa0, 0x7b, 0x04   # tail of `or %ah,0x47b(%bx,%si)` started at asm/6B3D
L_006ec7:
        mov    %al,0x479
L_006eca:
        mov    0x47c,%al
L_006ecd:
        stc
L_006ece:
        cmc
L_006ecf:
        sbb    $0x3,%al
L_006ed1:
        cmc
L_006ed2:
        mov    %al,0x47a
L_006ed5:
        call L_004daa
L_006ed8:
        incb   0x47a
L_006edc:
        call L_004daa
L_006edf:
        incb   0x47a
L_006ee3:
        call L_004daa
L_006ee6:
        incb   0x47a
L_006eea:
        call L_004daa
L_006eed:
        incb   0x47a
L_006ef1:
        call L_004daa
L_006ef4:
        incb   0x47a
L_006ef8:
        call L_004daa
L_006efb:
        incb   0x47a
L_006eff:
        call L_004daa
L_006f02:
        mov    0x47b,%al
L_006f05:
        stc
L_006f06:
        cmc
L_006f07:
        sbb    $0x3,%al
L_006f09:
        cmc
L_006f0a:
        mov    %al,0x479
L_006f0d:
        mov    0x47c,%al
L_006f10:
        mov    %al,0x47a
L_006f13:
        call L_004daa
L_006f16:
        incb   0x479
L_006f1a:
        call L_004daa
L_006f1d:
        incb   0x479
L_006f21:
        call L_004daa
L_006f24:
        incb   0x479
L_006f28:
        incb   0x479
L_006f2c:
        call L_004daa
L_006f2f:
        incb   0x479
L_006f33:
        call L_004daa
L_006f36:
        incb   0x479
L_006f3a:
        call L_004daa
L_006f3d:
        ret
