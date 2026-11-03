# restage_parked_rocket — second copy of the rocket restage stamp, different entry
# name-evidence: body is byte-for-byte the same stamp as asm/0839 -- DS:6A/DS:6B into the
#           target pair DS:23/DS:24, call the grid pointer L_0052b3, stamp $0x50 (the
#           rocket tile), then jmp L_000c33 which is cmd_done. Unlike asm/0839 this one
#           ends on the command-complete tail, so it is entered as a command arm rather
#           than as a subroutine of the load path.
# NAMED 2026-11-03 from a reader/writer sweep of the whole tree; it was a bulk-wave stub
#           headed "behavior not yet reviewed". What it does is settled by its bytes. WHO
#           JUMPS HERE is not -- no label reference to L_00265a was found in the corpus,
#           which is the same shape cmd_I, cmd_D and cmd_K had before the Phase 2 map was
#           re-cut: an `e8`/`e9` whose operand lives in the neighbouring fragment. The
#           caller is therefore an open question and is NOT claimed by this name.
#           See asm/38B0_cmd_L for the DS:69/6A/6B triple's semantics.
# func 245A..2473  len 001A B  evidence: seed+reko
# calls: L_000c33, L_0052b3
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_245a:
L_00265a:
        mov    0x6a,%al
L_00265d:
        mov    %al,0x23
L_002660:
        mov    0x6b,%al
L_002663:
        mov    %al,0x24
L_002666:
        call L_0052b3
L_002669:
        mov    $0x50,%al
L_00266b:
        mov    0x6,%bx
L_00266f:
        mov    %al,(%bx,%si)
L_002671:
        jmp L_000c33
