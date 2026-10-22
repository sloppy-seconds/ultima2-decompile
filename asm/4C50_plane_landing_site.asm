# plane_landing_site — location-description text block (landing-site context inferred)
# name-evidence: strings 'IN THE WATER.' / 'IN A MARSH.'
# func 4C50..4F10  len 02C1 B  evidence: seed+reko
# strings: "IN THE WATER."; "GGER"; "CE"; "ORD" (+48 more)
# provenance: live:airport (+22 other harvests), static
#           entry executed in 23 of 60 harvests; derived by tools/provenance_from_traces.py
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
plane_landing_site:
L_004e50:
        pop    %es
L_004e51:
        pop    %si
L_004e52:
        pop    %di
L_004e53:
        pop    %dx
L_004e54:
        ret
        db 0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00        # gap-pad
L_004e61:
        db "IN THE WATER.",0x00,"IN A MARSH.",0x00,"ON GRASS.",0x00,"IN WOODS.",0x00,"IN THE MTS.",0x00,"NEAR A VILLAGE.",0x00,"NEAR A TOWNE.",0x00,"NEAR A TOWER.",0x00,"NEAR A CASTLE.",0x00,"NEAR A DUNGEON.",0x00,"NEAR A SIGN.",0x00,"NEAR A HORSE.",0x00,"NEAR A FRIGATE.",0x00,"NEAR A PLANE.",0x00,"NEAR A ROCKET.",0x00,"NEAR ARMOUR.",0x00,"NEAR A HOLE.",0x00,"ON COBBLE.",0x00,"HANDS"        # string
L_004f58:
        add    %al,0x41(%si)
L_004f5b:
        db "GGER"        # string
L_004f5f:
        add    %cl,0x41(%di)
L_004f62:
        db "CE"        # string
L_004f64:
        add    %al,0x58(%bx,%di)
L_004f67:
        inc    %bp
L_004f68:
        add    %al,0x4f(%bp,%si)
L_004f6b:
        push   %di
L_004f6c:
        add    %dl,0x57(%bp,%di)
L_004f6f:
        db "ORD"        # string
L_004f72:
        add    %al,0x52(%bx)
L_004f75:
        db "EAT SWORD"        # string
L_004f7e:
        add    %cl,0x49(%si)
L_004f81:
        db "GHT SWORD"        # string
L_004f8a:
        add    %dl,0x48(%bx,%si)
L_004f8d:
        db "ASER"        # string
L_004f91:
        add    %dl,0x55(%bx,%di)
L_004f94:
        db "ICK SWORD"        # string
L_004f9d:
        add    %dl,0x4b(%bp,%di)
L_004fa0:
        db "IN"        # string
L_004fa2:
        add    %al,0x4c(%bp,%di)
L_004fa5:
        db "OTH"        # string
L_004fa8:
        add    %cl,0x45(%si)
L_004fab:
        db "ATHER"        # string
L_004fb0:
        add    %al,0x48(%bp,%di)
L_004fb3:
        db "AIN"        # string
L_004fb6:
        add    %dl,0x4c(%bx,%si)
L_004fb9:
        db "ATE"        # string
L_004fbc:
        add    %dl,0x45(%bp,%si)
L_004fbf:
        db "FLECT"        # string
L_004fc4:
        add    %dl,0x4f(%bx,%si)
L_004fc7:
        db "WER"        # string
L_004fca:
        add    %cl,0x4f(%bp)
L_004fcd:
        db "NE"        # string
L_004fcf:
        add    %cl,0x49(%si)
L_004fd2:
        db "GHT"        # string
L_004fd5:
        add    %al,0x4f(%si)
L_004fd8:
        db "WN LADDER"        # string
L_004fe1:
        add    %dl,0x50(%di)
L_004fe4:
        db " LADDER"        # string
L_004feb:
        add    %dl,0x41(%bx,%si)
L_004fee:
        db "SSWALL"        # string
L_004ff4:
        add    %dl,0x55(%bp,%di)
L_004ff7:
        db "RFACE"        # string
L_004ffc:
        add    %dl,0x52(%bx,%si)
L_004fff:
        db "AYER"        # string
L_005003:
        add    %cl,0x41(%di)
L_005006:
        db "GIC MISSILE"        # string
L_005011:
        add    %al,0x4c(%bp,%si)
L_005014:
        db "INK"        # string
L_005017:
        add    %cl,0x49(%bp,%di)
L_00501a:
        db "LL"        # string
L_00501c:
        add    %dl,0x49(%bp,%si)
L_00501f:
        db "NG"        # string
L_005021:
        add    %dl,0x41(%bx)
L_005024:
        db "ND"        # string
L_005026:
        add    %dl,0x54(%bp,%di)
L_005029:
        db "AFF"        # string
L_00502c:
        add    %al,0x4f(%bp,%si)
L_00502f:
        db "OTS"        # string
L_005032:
        add    %al,0x4c(%bp,%di)
L_005035:
        db "OAK"        # string
L_005038:
        add    %cl,0x45(%bx,%si)
L_00503b:
        db "LM"        # string
L_00503d:
        add    %al,0x45(%bx)
L_005040:
        dec    %bp
L_005041:
        add    %al,0x4e(%bx,%di)
L_005044:
        db "KH"        # string
L_005046:
        add    %dl,0x45(%bp,%si)
L_005049:
        db "D GEM"        # string
L_00504e:
        add    %dl,0x4b(%bp,%di)
L_005051:
        db "ULL KEY"        # string
L_005058:
        add    %al,0x52(%bx)
L_00505b:
        db "EEN GEM"        # string
L_005062:
        add    %al,0x52(%bp,%si)
L_005065:
        db "ASS BUTTON"        # string
L_00506f:
        add    %al,0x4c(%bp,%si)
L_005072:
        db "UE TASSLE"        # string
L_00507b:
        add    %dl,0x54(%bp,%di)
L_00507e:
        db "RANGE COIN"        # string
L_005088:
        add    %al,0x52(%bx)
L_00508b:
        db "EEN IDOL"        # string
L_005093:
        add    %dl,0x52(%si)
L_005096:
        db "I-LITHIUM"        # string
L_00509f:
        add    %dl,0x54(%bp,%di)
L_0050a2:
        db "RENGTH"        # string
L_0050a8:
        add    %al,0x47(%bx,%di)
L_0050ab:
        db "ILITY"        # string
L_0050b0:
        add    %dl,0x54(%bp,%di)
L_0050b3:
        db "AMINA"        # string
L_0050b8:
        add    %al,0x48(%bp,%di)
L_0050bb:
        db "ARISMA"        # string
L_0050c1:
        add    %dl,0x49(%bx)
L_0050c4:
        db "SDOM"        # string
L_0050c8:
        add    %cl,0x4e(%bx,%di)
L_0050cb:
        db "TELL.",0x00,"HUMAN"        # string
L_0050d6:
        add    %al,0x4c(%di)
L_0050d9:
        inc    %si
L_0050da:
        add    %al,0x57(%si)
L_0050dd:
        db "ARF"        # string
L_0050e0:
        add    %cl,0x4f(%bx,%si)
L_0050e3:
        db "BBIT"        # string
L_0050e7:
        add    %al,0x49(%bp)
L_0050ea:
        db "GHTER"        # string
L_0050ef:
        add    %al,0x4c(%bp,%di)
L_0050f2:
        db "ERIC"        # string
L_0050f6:
        add    %dl,0x49(%bx)
L_0050f9:
        db "ZARD"        # string
L_0050fd:
        add    %dl,0x48(%si)
L_005100:
        db "IEF"        # string
L_005103:
        add    %al,(%bx,%si)
L_005105:
        add    %al,(%bx,%si)
L_005107:
        add    %al,(%bx,%si)
L_005109:
        dec    %ax
L_00510a:
        push   %cs
L_00510b:
        push   %ax
L_00510c:
        sbb    %cx,0x5(%di)
L_00510f:
        dec    %bx
L_005110:
        pop    %ss
