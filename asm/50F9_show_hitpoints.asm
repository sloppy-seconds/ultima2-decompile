# show_hitpoints — status line: hit points
# name-evidence: string 'H.P.='
# func 50F9..5110  len 0018 B  evidence: seed+call+reko
# strings: "H.P.="
# calls: L_0051df (str_out)
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
show_hitpoints:
L_0052f9:
        mov    $0x28,%al
L_0052fb:
        mov    %al,0x31
L_0052fe:
        movb   $0x1e,0x2e
L_005303:
        mov    $0x14,%al
L_005305:
        mov    %al,0x2f
L_005308:
        call L_0051df
        db "H.P.=",0x00        # string
