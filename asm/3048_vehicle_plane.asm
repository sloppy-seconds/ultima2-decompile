# vehicle_plane — PLANE vehicle branch (can't-get-up gag)
# name-evidence: string ' PLANE' + 'STRANGE YOU CAN'T GET...'
# func 3048..310A  len 00C3 B  evidence: reko
# strings: " PLANE"; " PLANE"; " ROCKET"
# calls: L_000c30, L_000c33, L_0051df (str_out)
# provenance: static
#           entry never appears in ExecutedInstructions of any of the 60 harvests; derived by tools/provenance_from_traces.py
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
vehicle_plane:
L_003248:
        .byte 0x00,0x8b,0xf0,0x8b  # forced-kept: gas re-encodes 'add    %cl,-0x7410(%bp,%di)' differently
L_00324c:
        .byte 0x1e  # forced-kept: gas re-encodes 'push   %ds' differently
L_00324d:
        .byte 0x06  # forced-kept: gas re-encodes 'push   %es' differently
L_00324e:
        .byte 0x00,0x88,0x00,0xb0  # forced-kept: gas re-encodes 'add    %cl,-0x5000(%bx,%si)' differently
L_003252:
        .byte 0x24,0xa2  # forced-kept: gas re-encodes 'and    $0xa2,%al' differently
L_003254:
        .byte 0x13,0x00  # forced-kept: gas re-encodes 'adc    (%bx,%si),%ax' differently
L_003256:
        jmp L_000c33
L_003259:
        .byte 0x90  # forced-kept: gas re-encodes 'nop' differently
L_00325a:
        .byte 0xa0,0xdf,0x00  # forced-kept: gas re-encodes 'mov    0xdf,%al' differently
L_00325d:
        .byte 0x0a,0xc0  # forced-kept: gas re-encodes 'or     %al,%al' differently
L_00325f:
        jne L_003288
L_003261:
        call L_0051df
        db " PLANE",0x8d,"STRANGE YOU CAN'T GET IN!",0x00        # string
L_003285:
        jmp L_000c30
L_003288:
        .byte 0x90  # forced-kept: gas re-encodes 'nop' differently
L_003289:
        call L_0051df
        db " PLANE",0x00        # string
L_003293:
        .byte 0xb0,0x08  # forced-kept: gas re-encodes 'mov    $0x8,%al' differently
L_003295:
        .byte 0xb7,0x00  # forced-kept: gas re-encodes 'mov    $0x0,%bh' differently
L_003297:
        .byte 0xb3,0x00  # forced-kept: gas re-encodes 'mov    $0x0,%bl' differently
L_003299:
        .byte 0x8b,0xf3  # forced-kept: gas re-encodes 'mov    %bx,%si' differently
L_00329b:
        .byte 0x8b,0x1e,0x06,0x00  # forced-kept: gas re-encodes 'mov    0x6,%bx' differently
L_00329f:
        .byte 0x88,0x00  # forced-kept: gas re-encodes 'mov    %al,(%bx,%si)' differently
L_0032a1:
        .byte 0xb0,0x26  # forced-kept: gas re-encodes 'mov    $0x26,%al' differently
L_0032a3:
        .byte 0xa2,0x13,0x00  # forced-kept: gas re-encodes 'mov    %al,0x13' differently
L_0032a6:
        jmp L_000c33
L_0032a9:
        .byte 0x90  # forced-kept: gas re-encodes 'nop' differently
L_0032aa:
        call L_0051df
        db " ROCKET",0x00        # string
L_0032b5:
        .byte 0xa0,0xdd,0x00  # forced-kept: gas re-encodes 'mov    0xdd,%al' differently
L_0032b8:
        .byte 0x0a,0xc0  # forced-kept: gas re-encodes 'or     %al,%al' differently
L_0032ba:
        jne L_0032f4
L_0032bc:
        call L_0051df
        db 0x8d,"A METALIC VOICE COMMANDS:",0x8d,"YOU MUST HAVE AN ANKH!",0x00        # string
L_0032f1:
        jmp L_000c30
L_0032f4:
        .byte 0x90  # forced-kept: gas re-encodes 'nop' differently
L_0032f5:
        .byte 0xb0,0x08  # forced-kept: gas re-encodes 'mov    $0x8,%al' differently
L_0032f7:
        .byte 0xb7,0x00  # forced-kept: gas re-encodes 'mov    $0x0,%bh' differently
L_0032f9:
        .byte 0xb3,0x00  # forced-kept: gas re-encodes 'mov    $0x0,%bl' differently
L_0032fb:
        .byte 0x8b,0xf3  # forced-kept: gas re-encodes 'mov    %bx,%si' differently
L_0032fd:
        .byte 0x8b,0x1e,0x06,0x00  # forced-kept: gas re-encodes 'mov    0x6,%bx' differently
L_003301:
        .byte 0x88,0x00  # forced-kept: gas re-encodes 'mov    %al,(%bx,%si)' differently
L_003303:
        .byte 0xb0,0x28  # forced-kept: gas re-encodes 'mov    $0x28,%al' differently
L_003305:
        .byte 0xa2,0x13,0x00  # forced-kept: gas re-encodes 'mov    %al,0x13' differently
L_003308:
        jmp L_000c33
