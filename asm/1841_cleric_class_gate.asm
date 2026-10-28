# cleric_class_gate — the shrine's entry: only a Cleric may buy cleric spells
# func 1841..1848  len 0008 B  evidence: seed+reko
# name-evidence: `mov 0x47,%al ; cmp $0x1,%al ; je L_001a69`, and L_001a69 is
#           asm/1869_cleric_shrine. [DS:47] is the class byte (state.h `pclass`, 0 FIGHTER,
#           1 CLERIC, 2 WIZARD, 3 THIEF after `sub $0x31`), so this is the class gate the
#           handoff listed as unnamed in § 4.7: the field behind the NOT A CLERIC / NOT A
#           WIZARD guards is DS:47 and it was already named in engine/src/core/state.h.
#           Falling through reaches asm/184C_not_a_cleric_msg.
# note: this is one of the eight destinations of asm/1590_transact_shop_selector — the
#           east/south cell of a non-town site. The wizard half of the pair is
#           asm/19AF_wizard_class_gate.
# provenance: static
#           entry never appears in ExecutedInstructions of any harvest; derived by
#           tools/provenance_from_traces.py. The shrine behind it has never been reached in a
#           capture either — the gate is read, not observed.
# confidence: high (bytes proven by check_func.py; the target of the je is a named routine)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_1841:
L_001a41:
        nop
L_001a42:
        mov    0x47,%al
L_001a45:
        cmp    $0x1,%al
L_001a47:
        je L_001a69
