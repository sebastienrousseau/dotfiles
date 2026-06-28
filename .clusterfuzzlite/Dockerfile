# ClusterFuzzLite build environment for sebastienrousseau/dotfiles.
#
# Reuses the same Go fuzz harnesses as the OSS-Fuzz integration
# (oss-fuzz-integration/fuzz/). ClusterFuzzLite copies the checked-out
# repository into the image and runs .clusterfuzzlite/build.sh.

# hadolint ignore=DL3006
FROM gcr.io/oss-fuzz-base/base-builder-go

LABEL maintainer="Sebastien Rousseau <sebastian.rousseau@gmail.com>"

COPY . "$SRC/dotfiles"
WORKDIR "$SRC/dotfiles/oss-fuzz-integration/fuzz"
COPY .clusterfuzzlite/build.sh "$SRC/build.sh"
RUN chmod +x "$SRC/build.sh"
