# combat_kill_reward — monster killed: gold reward
# name-evidence: string 'KILLED--GOLD+'
# func 2D8C..2DB3  len 0028 B  evidence: seed+reko
# calls: L_0051df (str_out)
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
combat_kill_reward:
L_002f8c:
        mov    $0x0,%al
L_002f8e:
        mov    %al,0x1b7(%di)
L_002f92:
        mov    %al,0x177(%di)
L_002f96:
        mov    %al,0x137(%di)
L_002f9a:
        mov    %al,0x157(%di)
L_002f9e:
        mov    %al,0x197(%di)
L_002fa2:
        call L_0051df
        db 0x0d,"KILLED--GOLD+",0x00        # string
