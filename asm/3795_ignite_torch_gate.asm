# ignite_torch_gate — cmd_I's message and its site-kind gate
# name-evidence: the continuation of asm/3794 cmd_I, cut by the Phase 2 map after the call
#           opcode. Owns the text `IGNITE TORCH`, then `mov 0x4a,%al ; cmp $0x4 ; jae` — the same
#           kind gate as DESCEND and KLIMB, so a torch is only worth lighting in a tower or a
#           dungeon. Below that the command prints its own name and does nothing at all, which is
#           the handler rather than a gap in it.
# func 3795..37A3  len 000F B  evidence: reko; role read from the bytes 2026-10-29
# provenance: static — bytes read from asm/3794's call target and the site-kind compare here,
#           decoded 2026-10-29 alongside cmd_I. Not yet observed executing in a harvest.
# strings: "IGNITE TORCH"
# calls: L_0051df (str_out)
# confidence: high (handler role and gate read directly off the bytes, 2026-10-29)
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
