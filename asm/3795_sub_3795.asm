# sub_3795 — mechanical clean (bulk wave); behavior not yet reviewed
# func 3795..37A3  len 000F B  evidence: reko
# strings: "IGNITE TORCH"
# calls: L_0051df (str_out)
# confidence: low (bytes proven by check_func.py)
# body corrected: 2026-10-28e -- evidence: cmd_I's handler is the ordinary inline-string shape,
#           `call str_out / db text`, and the map cut the call after its opcode at asm/3794.
#           Every line this file showed was the string `IGNITE TORCH` decoded as code, plus the
#           two operand bytes of the call read as `dec %ax` and `sbb %cl,0x47(%bx,%di)`. Re-cut
#           from the call target (file 0051DF, str_out) and the NUL terminator. Found by
#           tools/forced_keep_audit.py and tools/str_out_audit.py.
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_3795:
L_003995:
        .byte 0x48, 0x18   # tail of `call L_0051df` (stop-trunc) started at asm/3794
L_003997:
        db "IGNITE TORCH",0x00        # string
