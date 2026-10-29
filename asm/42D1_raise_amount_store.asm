# raise_amount_store — parks the rung value at DS:1F and prints it
# name-evidence: every rung in asm/42AA..42CB jumps here with the chosen value in BL. It stores
#           [DS:1F] = bl, zeroes di, calls asm/53a5 (which renders the amount after the
#           'AND FOR IT I RAISE THEE ' string — the frame reads `@300`), and falls through to
#           asm/42E2 for the add.
# func 42D1..42E1  len 0011 B  evidence: seed+reko; role read from the bytes 2026-10-29
# calls: L_0053a5
# provenance: live:lord-british-tribute, static
# confidence: high
# notes: [DS:1F] is doing double duty here — the same byte is the TRANSACT cursor slot in
#           asm/3C2E cmd_O and asm/4050 cmd_T. Mode-dependent reuse again, the recurring pattern
#           with this byte (see also DS:26 and DS:49/4A).
# label: sub_42d1 / L_0044d1 kept as they are — labels are body (AGENTS.md § 3).
sub_42d1:
L_0044d1:
        .byte 0x8b,0xdf  # forced-kept: gas re-encodes 'mov    %di,%bx' differently
L_0044d3:
        mov    %bl,0x1f
L_0044d7:
        .byte 0x8b,0xc7  # forced-kept: gas re-encodes 'mov    %di,%ax' differently
L_0044d9:
        mov    $0x0,%bh
L_0044db:
        mov    $0x0,%bl
L_0044dd:
        .byte 0x8b,0xfb  # forced-kept: gas re-encodes 'mov    %bx,%di' differently
L_0044df:
        call L_0053a5
