# sub_4282 — mechanical clean (bulk wave); behavior not yet reviewed
# func 4282..428D  len 000C B  evidence: reko
# calls: L_002252
# confidence: low (bytes proven by check_func.py)
# body corrected: 2026-10-28e -- evidence: the first byte is the tail of `mov $0x50,%al`
#           (`b0 50`) whose opcode is the forced-keep at asm/4281; `push %ax` was 0x50 read as
#           an instruction. gas encodes `mov $0x50,%al` exactly, so the marker on 4281 blames
#           gas for a boundary. Found by tools/forced_keep_audit.py.
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_4282:
L_004482:
        .byte 0x50   # tail of `mov $0x50,%al` started at asm/4281
L_004483:
        mov    %al,0x28
L_004486:
        mov    $0x0,%al
L_004488:
        mov    %al,0x27
L_00448b:
        call L_002252
