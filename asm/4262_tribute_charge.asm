# tribute_charge — the 50 GP demand, and the price pair that pays it
# name-evidence: the string 'FIRST MY 50 G.P. TRIBUTE!'. Falls through from asm/4249 and hands
#           the price to asm/2052 in the pair asm/2052 expects: [DS:27] = 0x00 (high) and
#           [DS:28] = 0x50 (low). The order is easy to get backwards and state.h documents the
#           same wart on the gold pair itself (gold_lo at DS:58 is the HIGH byte). Read as
#           low-first this looks like a 5000 GP tribute; observed live it is 50.
# func 4262..4280  len 001F B  evidence: seed+reko
# calls: L_0051df (str_out)
# provenance: live:lord-british-tribute, static
#           CORRECTION 2026-10-29: the older "never appears in ExecutedInstructions" line was
#           overtaken by events. Gold was watched going 9999 -> 9949 -> 9899, so the charge is
#           50 and it fires on every offer including the ones that raise nothing.
# confidence: high
# notes: the spend happens BEFORE the raise ladder in asm/42AA..42CB is evaluated, so the
#           tribute is taken even on the +0 rung. Same shape as cmd_O, which spends before its
#           role dispatch. That is a design decision, not an oversight to fix.
# label: cleric_tribute kept as it is — labels are body (AGENTS.md § 3).
cleric_tribute:
L_004462:
        call L_0051df
        db 0x8d,"FIRST MY 50 G.P. TRIBUTE!",0x8d,0x00        # string
