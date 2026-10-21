# mode_table_copy — fills the movement mode bytes from a table, and swaps DS:13
# name-evidence: raw scan of the exe for direct writers of DS:15 and DS:18 (2026-10-21).
#           This block is the origin of the value the walk loop hands to 0x2423:
#           DS:2CB -> DS:15, DS:2DE -> DS:18, DS:2DF <-> DS:13, plus DS:16/DS:17
#           from DS:2F3/DS:2E0. A parallel block at runtime 0x5C4F does the same.
# OPEN: DS:2CB, DS:2DE, DS:2E0 and DS:2F3 have NO direct writers anywhere in the
#           exe (checked A2/A3/C6-06 forms over the whole file). They are filled
#           by an indirect store, and that is where the tile dependence of
#           passability must enter. Unresolved; docs/passability-findings.md F3.
# provenance: measured (raw byte scan of original/ultimaii.exe)
# func 5B71..5B97  len 0027 B  evidence: seed+reko
# calls: L_005e6d
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_5b71:
L_005d71:
        mov    0x2df,%al
L_005d74:
        mov    %al,0x14
L_005d77:
        mov    0x2cb,%al
L_005d7a:
        mov    %al,0x15
L_005d7d:
        mov    0x2f3,%al
L_005d80:
        mov    %al,0x16
L_005d83:
        mov    0x2de,%al
L_005d86:
        mov    %al,0x18
L_005d89:
        mov    0x2e0,%al
L_005d8c:
        mov    %al,0x17
L_005d8f:
        mov    0x13,%al
L_005d92:
        mov    %al,0x2df
L_005d95:
        jmp L_005e6d
