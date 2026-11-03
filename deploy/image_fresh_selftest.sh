#!/usr/bin/env bash
# image_fresh_selftest.sh — controls for deploy/image_fresh.sh.
#
# podman is replaced by a stub whose answers come from the environment, so these
# cases run on a machine with no containers and no daemon, which is what a gate
# needs. What is under test is the decision — rebuild or reuse — not podman.
#
# The case that matters most is "image exists but carries no label". That is every
# image built before the hash stamping existed, and the correct answer is to
# rebuild it. An image of unknown provenance must not be trusted to match a recipe
# it may predate, which is exactly the assumption that produced the stale-SDL2-image
# failure this file exists to prevent.

set -u

HERE="$(cd "$(dirname "$0")" && pwd)"
WORK="${WORK:-/var/tmp/u2-image-fresh-selftest}"
fail=0

ok()  { printf '  ok    %s\n' "$1"; }
bad() { printf '  FAIL  %s\n' "$1"; fail=$((fail+1)); }

rm -rf "$WORK"; mkdir -p "$WORK/bin"

# --- the stub -----------------------------------------------------------------
cat > "$WORK/bin/podman" <<'EOF'
#!/usr/bin/env bash
# Minimal podman stand-in. Answers come from STUB_* so each case can set them.
case "$1 $2" in
  "image exists")
      [ "${STUB_IMAGE_EXISTS:-0}" = "1" ] && exit 0 || exit 1 ;;
  "image inspect")
      [ "${STUB_INSPECT_FAIL:-0}" = "1" ] && exit 1
      printf '%s\n' "${STUB_LABEL:-}"
      exit 0 ;;
  "build "*)
      printf 'build' >> "${STUB_LOG:-/dev/null}"
      exit 0 ;;
esac
exit 0
EOF
chmod +x "$WORK/bin/podman"
export PATH="$WORK/bin:$PATH"

# --- a Containerfile to hash --------------------------------------------------
printf 'FROM scratch\nRUN echo one\n' > "$WORK/Containerfile"
SHA=$(sha256sum "$WORK/Containerfile" | cut -c1-16)
printf 'FROM scratch\nRUN echo two\n' > "$WORK/Containerfile-v2"
SHA2=$(sha256sum "$WORK/Containerfile-v2" | cut -c1-16)

# shellcheck source=image_fresh.sh
. "$HERE/image_fresh.sh"

# --- cases --------------------------------------------------------------------
# expect_current <what> <0|1> <env assignments...>
CF="$WORK/Containerfile"
expect_current() {
    local what="$1" want="$2"; shift 2
    local got
    if env "$@" bash -c ". '$HERE/image_fresh.sh'; u2_image_is_current u2-test '$CF'"; then
        got=0
    else
        got=1
    fi
    if [ "$got" = "$want" ]; then ok "$what"; else
        bad "$what: is_current=$got, wanted $want"; fi
}

expect_current "no image at all is not current" 1 \
    STUB_IMAGE_EXISTS=0
expect_current "image stamped with the same bytes is current" 0 \
    STUB_IMAGE_EXISTS=1 "STUB_LABEL=$SHA"
expect_current "image stamped with different bytes is not current" 1 \
    STUB_IMAGE_EXISTS=1 "STUB_LABEL=$SHA2"
expect_current "image with no label is not current (pre-stamp image)" 1 \
    STUB_IMAGE_EXISTS=1 STUB_LABEL=
expect_current "unreadable image metadata is not current" 1 \
    STUB_IMAGE_EXISTS=1 STUB_INSPECT_FAIL=1

# u2_containerfile_sha must fail loudly rather than hash an absent file.
if u2_containerfile_sha "$WORK/nope" >/dev/null 2>&1; then
    bad "u2_containerfile_sha returned a hash for a missing file"
else
    ok "missing Containerfile is an error, not an empty hash"
fi

# u2_image_build: reuse must not invoke podman build; a change must.
rm -f "$WORK/buildlog"
STUB_IMAGE_EXISTS=1 STUB_LABEL="$SHA" STUB_LOG="$WORK/buildlog" \
    u2_image_build u2-test "$WORK/Containerfile" >/dev/null 2>&1
[ -f "$WORK/buildlog" ] && bad "rebuild happened for an up-to-date image" \
                        || ok "up-to-date image is reused without a build"

rm -f "$WORK/buildlog"
STUB_IMAGE_EXISTS=1 STUB_LABEL="$SHA2" STUB_LOG="$WORK/buildlog" \
    u2_image_build u2-test "$WORK/Containerfile" >/dev/null 2>&1
[ -f "$WORK/buildlog" ] && ok "changed Containerfile triggers a build" \
                        || bad "no build after the Containerfile changed"

# The reason must name the staleness, or the log is back to being useless.
out=$(STUB_IMAGE_EXISTS=1 STUB_LABEL="$SHA2" STUB_LOG=/dev/null \
      u2_image_build u2-test "$WORK/Containerfile" 2>&1)
case "$out" in
    *"Containerfile changed"*) ok "the rebuild message says why" ;;
    *) bad "rebuild reason missing from the message: $out" ;;
esac

printf '\n'
if [ "$fail" -eq 0 ]; then
    printf 'IMAGE FRESH: PASS\n'
else
    printf 'IMAGE FRESH: FAIL (%d)\n' "$fail"
fi
exit "$fail"
