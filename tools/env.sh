# tools/env.sh — source this to wire the analysis tools for this project.
#
#   source tools/env.sh
#
# Spice86 and Reko are vendored under tools/ (gitignored, re-fetchable). Ghidra is too large to
# vendor and is Apache-2.0, so it is referenced by path rather than copied — this is the one
# external-tool path exception to the isolation rule (a tool binary, not project data). Override
# GHIDRA_HOME if your install lives elsewhere.

_U2V2_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

export GHIDRA_HOME="${GHIDRA_HOME:-/var/home/paul/Projects/ghidra-12.1.4}"
export SPICE86_DLL="$_U2V2_ROOT/tools/spice86/Spice86.dll"
export REKO_DLL="$_U2V2_ROOT/tools/reko/reko.dll"
export JWASM="$_U2V2_ROOT/tools/jwasm/jwasm"
export DOTNET_ROLL_FORWARD=Major

# Ghidra 12.1.4 needs JDK 21+ (no upper bound); the system JDK 25 is fine.
