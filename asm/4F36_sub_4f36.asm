# sub_4f36 — mechanical clean (bulk wave); behavior not yet reviewed
# func 4F36..4F4C  len 0017 B  evidence: seed+call+reko
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_4f36:
L_005136:
        stc
L_005137:
        mov    0x0,%al
L_00513a:
        sub    0x137(%di),%al
L_00513e:
        mov    %al,0x19
L_005141:
        stc
L_005142:
        mov    0x1,%al
L_005145:
        sub    0x157(%di),%al
L_005149:
        mov    %al,0x1a
L_00514c:
        ret
