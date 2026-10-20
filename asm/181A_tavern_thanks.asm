# tavern_thanks — tavern farewell
# name-evidence: string 'THANK YOU, COME AGAIN!'
# func 181A..183D  len 0024 B  evidence: seed+reko
# strings: "THANK YOU, COME AGAIN!"
# calls: L_0051df (str_out)
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
tavern_thanks:
L_001a1a:
        clc
L_001a1b:
        mov    0x53,%al
L_001a1e:
        adc    $0x1,%al
L_001a20:
        daa
L_001a21:
        mov    %al,0x53
L_001a24:
        call L_0051df
        db "THANK YOU, COME AGAIN!",0x00        # string
