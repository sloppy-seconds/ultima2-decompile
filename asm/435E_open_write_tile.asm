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
#           and re-entering was a question about the sector store; it is now answered (see
#           below) and the answer is no: the original writes no sector file at all, so the
#           paving lives only as long as the grid in DS does.
# PERSISTENCE (2026-10-29, owner-driven live session over noVNC, sector 31): two doors opened
#           at (42,17) and (49,17) both came back 0x70, the paving the player was standing
#           on, and both survived a walk through a town with 32 live creatures (38-odd cells
#           churned by movement, the two openings intact). Leaving the sector and re-entering
#           closed them: `mapx31` in the run dir is byte-identical to the pristine copy, and
#           so are `monx31`, `mapx30` and `monx30` -- the only file the game writes back is
#           `player`. So the paving is real and durable within a visit and gone on reload.
# label: kept as sub_435e on purpose (CP3 cross-reference anchor).
# func 435E..437D  len 0020 B  evidence: seed+reko
# calls: L_000c33
# provenance: static reassembly 2026-10-28; the two DS:14 reads are from the g30 sessions;
#           persistence half from the 2026-10-29 noVNC session (owner playing, DS read live
#           over the HTTP API, run dir /var/tmp/u2/spice86-runs/20261028-012747)
# confidence: high for the mechanism. The ground-paving rule is now confirmed by THREE
#           completed unlocks with three DIFFERENT ground values -- 0x0C (the scripted
#           unlock1 run, recorded in docs/needs-gameplay.md G30), 0x08 and 0x70 (this
#           session). An earlier line here said the rule had "not yet been confirmed by a
#           completed unlock"; that was stale against needs-gameplay, and it is wrong now
#           in both directions.
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
