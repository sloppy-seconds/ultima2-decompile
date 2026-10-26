# cmd_S — command handler 'S': prints "STEAL DIRECT-" then falls through
# func 3F25..3F35  len 017 B  evidence: seed+reko (jump table cs:0730 entry S)
# provenance: live:cmd-letters2-20261025; static
#           entry executed in 2 of 149 harvests; confirmed by the capture of 2026-10-25. The
#           capture proves the entry ran and nothing more -- what the following direction did
#           with the aim is not established by these two harvests. Was recorded as never
#           executed against a 60-harvest corpus that has since grown.
# confidence: high
cmd_S:
        call L_0051df          # str_out — prints the inline string below
        db "STEAL DIRECT-",0   # string
