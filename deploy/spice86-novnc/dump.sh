#!/usr/bin/env bash
# Harvest the live noVNC container's CFG + execution trace.
#
# Why this exists: deploy/spice86-novnc/up.sh --down performs no dump at all, and
# headless Spice86 ignores SIGTERM, so tearing the container down silently discards
# the one artefact that proves code executed. tools/spice86_stop.sh already knows how
# to dump over the GDB port, so this reuses its library instead of hand-rolling the
# GDB conversation.
set -euo pipefail
cd "$(dirname "$0")/../.."        # project root
. tools/spice86_common.sh

GDB="${1:-20190}"
echo "monitor dumpAll -> gdb 127.0.0.1:${GDB}"
if s86_dumpall_live "$GDB"; then
    echo "dump ok"
else
    echo "dump FAILED (gdb port closed or busy)" >&2
    exit 1
fi
