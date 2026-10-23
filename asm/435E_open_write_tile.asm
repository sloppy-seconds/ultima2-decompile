# 435E_open_write_tile — consume one key (BCD) and pave the door with your own ground
# name-evidence: the BCD decrement `stc; mov 0x65,%al; cmc; sbb $0x1,%al; das; cmc;
#           mov %al,0x65` is asm/433E's key check paying off, and the tail is the answer
#           to handoff item 5 / G30.
# THE BYTE: `mov 0x14,%al ; add %al,%al` writes `DS:14 * 2`. DS:14 is the tile under the
#           PLAYER shifted right one (site_check.c already records `DS:14 = map_byte >> 1`
#           from cmd_E), so `DS:14 * 2` is the player's own ground tile with the low bit
#           cleared. Checked against two live reads taken this session: sector 32 with the
#           player on 0x08 gave DS:14 = 4, and sector 20 on 0x0C gave DS:14 = 6. Both are
#           exactly `ground >> 1`, so opening a door paves it with the ground you are
#           standing on. That is the named answer the handoff asked for instead of an
#           invented constant, and it is falsifiable: unlock from forest and the cell must
#           come back 0x0C.
# THE ADDRESS: DI is zeroed and `mov 0x6(%di),%bx` loads BX from DS:06, which is where
#           asm/50B3_map_tile_ptr left the pointer it just computed (`mov %bx,0x6`). So the
#           write goes through the SAME pointer the door test read -- into the live sector
#           grid in DS, not a separate overlay and not the file. Whether it survives leaving
#           and re-entering is therefore a question about the sector store (asm/22FD), not
#           about this instruction.
# label: kept as sub_435e on purpose (CP3 cross-reference anchor).
# func 435E..437D  len 0020 B  evidence: seed+reko
# calls: L_000c33
# provenance: static reassembly 2026-10-28; the two DS:14 reads are from the g30 sessions
# confidence: high for the mechanism; the ground-paving rule is two-for-two on live reads
#           and has not yet been confirmed by a completed unlock
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_435e:
L_00455e:
        stc
L_00455f:
        mov    0x65,%al
L_004562:
        cmc
L_004563:
        sbb    $0x1,%al
L_004565:
        das
L_004566:
        cmc
L_004567:
        mov    %al,0x65
L_00456a:
        mov    0x14,%al
L_00456d:
        .byte 0x02,0xc0  # forced-kept: gas re-encodes 'add    %al,%al' differently
L_00456f:
        mov    $0x0,%bh
L_004571:
        mov    $0x0,%bl
L_004573:
        .byte 0x8b,0xfb  # forced-kept: gas re-encodes 'mov    %bx,%di' differently
L_004575:
        .byte 0x8b,0x9d,0x06,0x00  # forced-kept: gas re-encodes 'mov    0x6(%di),%bx' differently
L_004579:
        mov    %al,(%bx)
L_00457b:
        jmp L_000c33
