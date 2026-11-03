#!/usr/bin/env bash
# image_fresh.sh — decide whether a container image still matches its recipe.
#
# The bug this kills: `build.sh` used to rebuild only when the image did not exist
# at all. Edit a Containerfile, run build.sh, and it silently reused the stale
# image and reported a failure that looked like a bug in the new recipe. That is
# how both SDL3 container builds "failed" on 2026-11-03 — they were building
# against the old SDL2 image, and the error said "static SDL3 not found", which
# pointed at the Makefile instead of at the thing that was wrong.
#
# A timestamp comparison would be the obvious fix and would lie: git checkout
# rewrites mtimes, a copied tree resets them, and an image can be older than a
# Containerfile it was legitimately built from. So compare content instead. The
# sha256 of the Containerfile is stamped onto the image as a label at build time,
# and freshness means "the label matches the bytes on disk right now".
#
# Side effect worth knowing: every image built before this change carries no
# label, so each one rebuilds exactly once after this lands. That is the correct
# outcome — an image of unknown provenance should not be trusted to match anything.
#
# Sourced by deploy/*/build.sh. Selftest: deploy/image_fresh_selftest.sh.

U2_IMAGE_LABEL="io.u2.containerfile-sha"

# u2_containerfile_sha PATH -> first 16 hex chars of the file's sha256.
u2_containerfile_sha() {
    local src="$1"
    [ -f "$src" ] || return 1
    sha256sum "$src" | cut -c1-16
}

# u2_image_label IMAGE -> the stamped sha, or empty if absent/unreadable.
u2_image_label() {
    local image="$1"
    podman image inspect "$image" \
        --format "{{ index .Config.Labels \"$U2_IMAGE_LABEL\" }}" 2>/dev/null
}

# u2_image_is_current IMAGE CONTAINERFILE -> 0 when the image exists AND was built
# from exactly these bytes. Non-zero for every other case, including "cannot tell",
# because an unknown image must be rebuilt rather than trusted.
u2_image_is_current() {
    local image="$1" src="$2" want got
    want=$(u2_containerfile_sha "$src") || return 1
    podman image exists "$image" >/dev/null 2>&1 || return 1
    got=$(u2_image_label "$image") || return 1
    [ -n "$got" ] && [ "$got" = "$want" ]
}

# u2_image_build IMAGE CONTAINERFILE [-- extra podman build args]
# Build only if needed, stamping the recipe hash. Echoes why it rebuilt, so a log
# says which of the two reasons applied.
u2_image_build() {
    local image="$1" src="$2"; shift 2
    local sha reason
    sha=$(u2_containerfile_sha "$src") || { echo "image_fresh: no Containerfile at $src" >&2; return 1; }

    if u2_image_is_current "$image" "$src"; then
        return 0
    fi

    if ! podman image exists "$image" >/dev/null 2>&1; then
        reason="not built yet"
    else
        reason="Containerfile changed since it was built (stamped '$(u2_image_label "$image")', now '$sha')"
    fi
    echo "image_fresh: rebuilding $image — $reason"
    podman build "$@" --label "${U2_IMAGE_LABEL}=${sha}" -t "$image" -f "$src" "$(dirname "$src")"
}
