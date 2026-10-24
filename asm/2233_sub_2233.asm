# sub_2233 — restore the old cell, then commit. `mov 0x1b7(%di),%al` + `mov %al,(%bx,%si)`
#           writes DS:1B7[di] back into the grid cell DS:6 addresses, i.e. the terrain that
#           was under this creature before it moved. Then DS:27/DS:28 become mon_x/mon_y and
#           the new cell is fetched. THIS is what DS:1B7 is for: the per-slot saved terrain
#           byte, written the same way by asm/0CEE_spawn_tile_store at spawn and read by the
#           spawn arms' `cmp $0x8,%al` guards.
# func 2233..2259  len 0027 B  evidence: seed+reko
# apple2-twin: $66C5 in ULTIMA.II.OBJ, and the pair continues into asm/225A's twin at $6701.
#           Hand-decoded: `LDA $4D80,X ; LDY #$0091 ; STA ($06),Y` is this file's
#           `mov 0x1b7(%di),%al` + `mov %al,(%bx,%si)` — the per-slot saved terrain byte
#           written back into the grid through the same kind of indirection (zero-page pointer
#           $06 on the Apple, DS:6 on the DOS), then the candidate pair is committed to
#           $4D00,X/$4D20,X and the tile re-fetched with `JSR $4015`, the vector for $4377,
#           which takes the candidate pair $F4/$F5, folds it into a pointer in $06/$07 and
#           returns the byte there — the same role as asm/50B3_map_tile_ptr, and only the
#           role: the arithmetic is not the DOS y*64+x layout, and whether $4377 reads the
#           sector grid or the screen is NOT settled here. Fourth witness for DS:1B7, which was the ask: three DOS
#           sites said the same thing and this is an independent implementation agreeing. The
#           table mapping it fixes — $4D00/$4D20/$4D60/$4D80 = DS:137/157/197/1B7 — is
#           corroborated, not observed, and does not rename this file.
# calls: L_0052b3
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_2233:
L_002433:
        mov    0x1b7(%di),%al
L_002437:
        mov    $0x0,%bh
L_002439:
        mov    $0x0,%bl
L_00243b:
        .byte 0x8b,0xf3  # forced-kept: gas re-encodes 'mov    %bx,%si' differently
L_00243d:
        mov    0x6,%bx
L_002441:
        mov    %al,(%bx,%si)
L_002443:
        mov    0x27,%al
L_002446:
        mov    %al,0x23
L_002449:
        mov    %al,0x137(%di)
L_00244d:
        mov    0x28,%al
L_002450:
        mov    %al,0x24
L_002453:
        mov    %al,0x157(%di)
L_002457:
        call L_0052b3
