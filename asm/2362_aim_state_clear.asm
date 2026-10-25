# aim_state_clear — the aim gate's prologue: zero the direction state, then block for a key
# name-evidence: read directly -- mov 0,%al then four stores to DS:1F, DS:20, DS:19, DS:1A,
#           then a call to the key reader at 0x4F4D and a `cmp ah,0xff` bail-out test.
#           DS:19/DS:1A are the aim deltas: asm/3F37 (cmd_S's fall-through) turns around and
#           computes the target as ([DS:00]+[DS:19], [DS:01]+[DS:1A]) into DS:23/DS:24.
# callers:  asm/4307 (cmd_U UNLOCK), asm/3F37 (cmd_S STEAL), asm/3C2E (cmd_O OFFER),
#           asm/2BBE, asm/35EB. That set is the whole aim-gate family, and it is worth naming
#           because two nearby commands are NOT in it: cmd_C takes no direction at all
#           (asm/310B), and cmd_T aims by a cursor initialiser and slot scan instead
#           (asm/23E6). "The direction commands" is not a uniform set.
# provenance: live
#           entry observed in ExecutedInstructions of 54 of the 142 harvests that carry a flow
#           dump (controls: 0x4F4D 142/142). The continuation at 0x2370 shows in the same 54.
# func 2362..236F  len 000E B  evidence: seed+call+reko
# note: this file holds the CLEAR only. The key wait at 0x2370 and the `cmp ah,0xff` at 0x2373
#           are in the following tiling fragments -- a known fragment split, see
#           disasm/fragment-splits.tsv. The name is on the entry point.
# note: DS:1F is one of the most heavily aliased bytes in the data segment (twenty-plus
#           writers); this is one of them, and it writes zero.
# confidence: high (bytes proven by check_func.py; the stores, the callers and the execution
#             evidence all agree)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_2362:
L_002562:
        mov    $0x0,%al
L_002564:
        mov    %al,0x1f
L_002567:
        mov    %al,0x20
L_00256a:
        mov    %al,0x19
L_00256d:
        mov    %al,0x1a
