# cmd_Q — command handler 'Q': prints "QUIT OR SAVE GAME." then falls through
# func 3DC7..3DDC  len 022 B  evidence: seed+reko (jump table cs:0730 entry Q)
# provenance: live:play-test (+2 other harvests), static
#           entry executed in 5 of 150 harvests; derived by tools/provenance_from_traces.py
# confidence: high
cmd_Q:
        call L_0051df          # str_out — prints the inline string below
        db "QUIT OR SAVE GAME.",0   # string
