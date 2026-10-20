# sub_48ca — mechanical clean (bulk wave); behavior not yet reviewed
# func 48CA..4A1B  len 0152 B  evidence: seed+reko
# calls: L_000c33, L_004b52, L_004b56
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_48ca:
L_004aca:
        jmp L_000c33
L_004acd:
        db 0x00,0x00  # split: branch target inside data
L_004acf:
        db 0x00,0xc0  # split: branch target inside data
L_004ad1:
        db 0x30,0x0c  # split: branch target inside data
L_004ad3:
        db 0x03,0xff  # split: branch target inside data
L_004ad5:
        db 0x11,0x88,0xcc,0x33  # split: branch target inside data
L_004ad9:
        db 0x00,0x00  # split: branch target inside data
L_004adb:
        db 0x00,0x00  # split: branch target inside data
L_004add:
        db 0xb8,0x00,0xba  # split: branch target inside data
L_004ae0:
        db 0x05,0xb8,0x05  # split: branch target inside data
L_004ae3:
        db 0xba,0x0a,0xb8  # split: branch target inside data
L_004ae6:
        db 0x0a,0xba,0x0f,0xb8  # split: branch target inside data
L_004aea:
        db 0x0f,0xba  # split: branch target inside data
L_004aec:
        db 0x14,0xb8  # split: branch target inside data
L_004aee:
        db 0x14,0xba  # split: branch target inside data
L_004af0:
        db 0x19,0xb8,0x19,0xba  # split: branch target inside data
L_004af4:
        db 0x1e  # split: branch target inside data
L_004af5:
        db 0xb8  # split: branch target inside data
L_004af6:
        db 0x1e,0xba  # split: branch target inside data
L_004af8:
        db 0x23,0xb8  # split: branch target inside data
L_004afa:
        db 0x23,0xba  # split: branch target inside data
L_004afc:
        db 0x28,0xb8  # split: branch target inside data
L_004afe:
        db 0x28,0xba  # split: branch target inside data
L_004b00:
        db 0x2d,0xb8,0x2d  # split: branch target inside data
L_004b03:
        db 0xba,0x32,0xb8  # split: branch target inside data
L_004b06:
        db 0x32,0xba,0x37,0xb8  # split: branch target inside data
L_004b0a:
        db 0x37  # split: branch target inside data
L_004b0b:
        db 0xba,0x3c,0xb8  # split: branch target inside data
L_004b0e:
        db 0x3c,0xba  # split: branch target inside data
L_004b10:
        db 0x41  # split: branch target inside data
L_004b11:
        db 0xb8,0x41,0xba  # split: branch target inside data
L_004b14:
        db 0x46  # split: branch target inside data
L_004b15:
        db 0xb8,0x46,0xba  # split: branch target inside data
L_004b18:
        db 0x4b  # split: branch target inside data
L_004b19:
        db 0xb8,0x4b,0xba  # split: branch target inside data
L_004b1c:
        db 0x50  # split: branch target inside data
L_004b1d:
        db 0xb8,0x50,0xba  # split: branch target inside data
L_004b20:
        db 0x55  # split: branch target inside data
L_004b21:
        db 0xb8,0x55,0xba  # split: branch target inside data
L_004b24:
        db 0x5a  # split: branch target inside data
L_004b25:
        db 0xb8,0x5a,0xba  # split: branch target inside data
L_004b28:
        db 0x5f  # split: branch target inside data
L_004b29:
        db 0xb8,0x5f,0xba  # split: branch target inside data
L_004b2c:
        db 0x64,0xb8,0x64,0xba  # split: branch target inside data
L_004b30:
        db 0x69,0xb8,0x69,0xba,0x6e,0xb8  # split: branch target inside data
L_004b36:
        db 0x6e  # split: branch target inside data
L_004b37:
        db 0xba,0x73,0xb8  # split: branch target inside data
L_004b3a:
        jae L_004af6
L_004b3c:
        js L_004af6
L_004b3e:
        js L_004afa
L_004b40:
        jge L_004afa
L_004b42:
        jge L_004afe
L_004b44:
        db 0x82,0xb8,0x82,0xba,0x87  # split: branch target inside data
L_004b49:
        db 0xb8  # split: branch target inside data
L_004b4a:
        db 0x87,0xba  # split: branch target inside data
L_004b4c:
        db 0x8c,0xb8  # split: branch target inside data
L_004b4e:
        db 0x8c,0xba  # split: branch target inside data
L_004b50:
        db 0x91  # split: branch target inside data
L_004b51:
        db 0xb8  # split: branch target inside data
L_004b52:
        db 0x91,0xba  # split: branch target inside data
L_004b54:
        db 0x96  # split: branch target inside data
L_004b55:
        db 0xb8  # split: branch target inside data
L_004b56:
        db 0x96,0xba  # split: branch target inside data
L_004b58:
        db 0x9b  # split: branch target inside data
L_004b59:
        db 0xb8,0x9b,0xba  # split: branch target inside data
L_004b5c:
        db 0xa0,0xb8,0xa0  # split: branch target inside data
L_004b5f:
        db 0xba,0xa5,0xb8  # split: branch target inside data
L_004b62:
        db 0xa5  # split: branch target inside data
L_004b63:
        db 0xba,0xaa,0xb8  # split: branch target inside data
L_004b66:
        db 0xaa  # split: branch target inside data
L_004b67:
        db 0xba,0xaf,0xb8  # split: branch target inside data
L_004b6a:
        db 0xaf  # split: branch target inside data
L_004b6b:
        db 0xba,0xb4,0xb8  # split: branch target inside data
L_004b6e:
        db 0xb4,0xba  # split: branch target inside data
L_004b70:
        db 0xb9,0xb8,0xb9  # split: branch target inside data
L_004b73:
        db 0xba,0xbe,0xb8  # split: branch target inside data
L_004b76:
        db 0xbe,0xba,0xc3  # split: branch target inside data
L_004b79:
        db 0xb8,0xc3,0xba  # split: branch target inside data
L_004b7c:
        db 0xc8,0xb8,0xc8,0xba  # split: branch target inside data
L_004b80:
        db 0xcd,0xb8  # split: branch target inside data
L_004b82:
        db 0xcd,0xba  # split: branch target inside data
L_004b84:
        db 0xd2,0xb8,0xd2,0xba  # split: branch target inside data
L_004b88:
        db 0xd7  # split: branch target inside data
L_004b89:
        db 0xb8,0xd7,0xba  # split: branch target inside data
L_004b8c:
        db 0xdc,0xb8,0xdc,0xba  # split: branch target inside data
L_004b90:
        loope L_004b4a
L_004b92:
        loope L_004b4e
L_004b94:
        db 0xe6,0xb8  # split: branch target inside data
L_004b96:
        db 0xe6,0xba  # split: branch target inside data
L_004b98:
        jmp L_004b52
L_004b9a:
        jmp L_004b56
L_004b9c:
        db 0xf0,0xb8,0xf0,0xba  # split: branch target inside data
L_004ba0:
        db 0xf5  # split: branch target inside data
L_004ba1:
        db 0xb8,0xf5,0xba  # split: branch target inside data
L_004ba4:
        db 0xfa  # split: branch target inside data
L_004ba5:
        db 0xb8,0xfa,0xba  # split: branch target inside data
L_004ba8:
        db 0xff  # split: branch target inside data
L_004ba9:
        db 0xb8,0xff,0xba  # split: branch target inside data
L_004bac:
        db 0x04,0xb9  # split: branch target inside data
L_004bae:
        db 0x04,0xbb  # split: branch target inside data
L_004bb0:
        db 0x09,0xb9,0x09,0xbb  # split: branch target inside data
L_004bb4:
        db 0x0e  # split: branch target inside data
L_004bb5:
        db 0xb9,0x0e,0xbb  # split: branch target inside data
L_004bb8:
        db 0x13,0xb9,0x13,0xbb  # split: branch target inside data
L_004bbc:
        db 0x18,0xb9,0x18,0xbb  # split: branch target inside data
L_004bc0:
        db 0x1d,0xb9,0x1d  # split: branch target inside data
L_004bc3:
        db 0xbb,0x22,0xb9  # split: branch target inside data
L_004bc6:
        db 0x22  # split: branch target inside data
L_004bc7:
        db 0xbb,0x27,0xb9  # split: branch target inside data
L_004bca:
        db 0x27  # split: branch target inside data
L_004bcb:
        db 0xbb,0x2c,0xb9  # split: branch target inside data
L_004bce:
        db 0x2c,0xbb  # split: branch target inside data
L_004bd0:
        db 0x31,0xb9,0x31,0xbb  # split: branch target inside data
L_004bd4:
        db 0x36,0xb9,0x36,0xbb  # split: branch target inside data
L_004bd8:
        db 0x3b,0xb9,0x3b,0xbb  # split: branch target inside data
L_004bdc:
        db 0x40  # split: branch target inside data
L_004bdd:
        db 0xb9,0x40,0xbb  # split: branch target inside data
L_004be0:
        db 0x45  # split: branch target inside data
L_004be1:
        db 0xb9,0x45,0xbb  # split: branch target inside data
L_004be4:
        db 0x4a  # split: branch target inside data
L_004be5:
        db 0xb9,0x4a,0xbb  # split: branch target inside data
L_004be8:
        db 0x4f  # split: branch target inside data
L_004be9:
        db 0xb9,0x4f,0xbb  # split: branch target inside data
L_004bec:
        db 0x54  # split: branch target inside data
L_004bed:
        db 0xb9,0x54,0xbb  # split: branch target inside data
L_004bf0:
        db 0x59  # split: branch target inside data
L_004bf1:
        db 0xb9,0x59,0xbb  # split: branch target inside data
L_004bf4:
        db 0x5e  # split: branch target inside data
L_004bf5:
        db 0xb9,0x5e,0xbb  # split: branch target inside data
L_004bf8:
        db 0x63,0xb9,0x63,0xbb  # split: branch target inside data
L_004bfc:
        db 0x68,0xb9,0x68  # split: branch target inside data
L_004bff:
        db 0xbb,0x6d,0xb9  # split: branch target inside data
L_004c02:
        db 0x6d  # split: branch target inside data
L_004c03:
        db 0xbb,0x72,0xb9  # split: branch target inside data
L_004c06:
        jb L_004bc3
L_004c08:
        ja L_004bc3
L_004c0a:
        ja L_004bc7
L_004c0c:
        jl L_004bc7
L_004c0e:
        jl L_004bcb
L_004c10:
        db 0x81,0xb9,0x81,0xbb,0x86,0xb9  # split: branch target inside data
L_004c16:
        db 0x86,0xbb,0x8b,0xb9  # split: branch target inside data
L_004c1a:
        db 0x8b,0xbb  # split: branch target inside data
