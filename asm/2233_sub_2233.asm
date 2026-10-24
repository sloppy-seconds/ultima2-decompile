# sub_2233 — restore the old cell, then commit. `mov 0x1b7(%di),%al` + `mov %al,(%bx,%si)`
#           writes DS:1B7[di] back into the grid cell DS:6 addresses, i.e. the terrain that
#           was under this creature before it moved. Then DS:27/DS:28 become mon_x/mon_y and
#           the new cell is fetched. THIS is what DS:1B7 is for: the per-slot saved terrain
#           byte, written the same way by asm/0CEE_spawn_tile_store at spawn and read by the
#           spawn arms' `cmp $0x8,%al` guards.
# func 2233..2259  len 0027 B  evidence: seed+reko
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
