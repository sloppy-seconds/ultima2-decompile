# cmd_K — command handler 'K': prints an inline string; call operand and text
#           live in the following map fragment (37F2..) — one-byte opcode here.
# func 37F1..37F1  len 001 B  evidence: seed+reko (jump table cs:0730 entry K)
# provenance: live:airport32 (+2 other harvests), static
#           entry executed in 3 of 172 harvests; derived by tools/provenance_from_traces.py
# confidence: high (handler role proven; split is a map-boundary artifact)
# notes: stop-trunc — do not "fix" to `call`; operand bytes are outside range
cmd_K:
        .byte 0xe8             # forced-kept: stop-trunc call   0x51df
