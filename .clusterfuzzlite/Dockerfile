# ClusterFuzzLite build environment for sebastienrousseau/dotfiles.
#
# Reuses the same Go fuzz harnesses as the OSS-Fuzz integration
# (fuzz/). ClusterFuzzLite copies the checked-out
# repository into the image and runs .clusterfuzzlite/build.sh.

# hadolint ignore=DL3006
FROM gcr.io/oss-fuzz-base/base-builder-go@sha256:1dbadefbb28c6bfd796c64d9c2115977deb8f19494533cc5a3b724c3441df23d

LABEL maintainer="Sebastien Rousseau <sebastienrousseau@users.noreply.github.com>"

COPY . "$SRC/dotfiles"
WORKDIR "$SRC/dotfiles/fuzz"
COPY .clusterfuzzlite/build.sh "$SRC/build.sh"
RUN chmod +x "$SRC/build.sh"
