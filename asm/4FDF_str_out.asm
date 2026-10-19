# str_out — inline-string display entry: tail-calls the real routine at
#           file 0x53fd (seg 51FD). Callers place the NUL-terminated message
#           right after the 3-byte call (see cmd_* handlers).
# func 4FDF..4FE1  len 003 B  evidence: seed+call+reko
# confidence: high (entry point proven by 57 call sites; wrapper shape proven by bytes)
str_out:
L_0051df:
        call L_0053fd
