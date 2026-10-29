# cmd_F — command handler 'F': prints "FIRE" then falls
#           through into the following map fragment
# func 35C1..35C8  len 008 B  evidence: seed+reko (jump table cs:0730 entry F)
# provenance: live:airport32 (+3 other harvests), static
#           entry executed in 4 of 187 harvests; derived by tools/provenance_from_traces.py
# confidence: high (handler role proven; message literal)
# name-evidence: read 2026-10-29. FIRE is the FRIGATE'S CANNONS, not a melee attack, and the
#           mode gate says so: asm/35C9 reads [DS:13], the travel-mode stamp, and continues
#           only on 0x24, which is the ship value from asm/2FAD's BOARD dispatch (0x22 horse,
#           0x24 ship, 0x26 plane). Anywhere else the tail prints " WHAT?" at asm/35D0, so on
#           foot the whole command is `FIRE WHAT?`. On the frigate it prints " DIRECT-" at
#           asm/35DE and goes through the aim gate at asm/35EA -- an aimed cannon, the same
#           family as cmd_A/S/U/T.
#           This corrects `engine/src/game/commands.c`, which had filed F as "the combat/
#           attack arm" from the bare word FIRE. cmd_A is the attack; F is a vehicle weapon.
#           Owner recollection supplied the pointer, the mode byte confirmed it.
cmd_F:
        call L_0051df          # str_out — prints the inline string below
        db "FIRE",0        # string
