# data_486d — DATA ISLAND, not code: Phase 2 defect verdict
#            (disasm/defects.md): the region decodes only as absurd instructions
#            (fisttps / negative displacements); bytecheck FP adjudicated.
#            CP5 disposition: data. Bytes byte-proven via check_func.py.
# func 486D..4879  len 000D B  evidence: reko (island inside seed range)
# provenance: static
#           entry never appears in ExecutedInstructions of any of the 60 harvests; derived by tools/provenance_from_traces.py
# confidence: high (defect verdict documented)
data_486d_mixed:
L_004a6d:
        db 0xdf,0x88,0x1e,0x1f,0x00,0x8b,0xc7,0xf8,0x14,0x2e,0xe8,0x12,0x08        # mixed: island bytes
