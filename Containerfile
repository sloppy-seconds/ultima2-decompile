# Minimal reproducible build environment for the Ultima II reconstruction.
# The image build itself rebuilds the tree and verifies it against the known
# checksum — no game files are required or included (see .dockerignore).
#
#   podman build -t u2-rebuild .
#   podman run --rm -v "$PWD/build:/out:Z,U" u2-rebuild
#   (:Z,U = SELinux label + ownership remap for rootless podman on Fedora)
#
# Docker: docker build -f Containerfile -t u2-rebuild .
FROM quay.io/fedora/fedora:41
RUN dnf -y install binutils python3 && dnf clean all
WORKDIR /src
COPY . /src
RUN bash tools/assemble_clean.sh /tmp/verify.bin
CMD ["bash", "tools/assemble_clean.sh", "/out/u2-clean-rebuild.bin"]
