# cmd_I — command handler 'I': prints an inline string whose call operand and
#           text live in the following map fragment (3795..37A3) — the one-byte
#           call opcode is all this range holds.
# func 3794..3794  len 001 B  evidence: seed+reko (jump table cs:0730 entry I)
# provenance: live:airport (+4 other harvests), static
#           entry executed in 7 of 167 harvests; derived by tools/provenance_from_traces.py
# confidence: high (handler role proven; split is a map-boundary artifact)
# notes: stop-trunc — do not "fix" to `call`; operand bytes are outside range
cmd_I:
        .byte 0xe8             # forced-kept: stop-trunc call   0x51df
