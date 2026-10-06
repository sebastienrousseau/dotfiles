# ClusterFuzzLite build environment for sebastienrousseau/dotfiles.
#
# Reuses the same Go fuzz harnesses as the OSS-Fuzz integration
# (fuzz/). ClusterFuzzLite copies the checked-out
# repository into the image and runs .clusterfuzzlite/build.sh.

# hadolint ignore=DL3006
FROM gcr.io/oss-fuzz-base/base-builder-go@sha256:1fd52de184d67413e027f2534dc0dde8fec60f17c70dac7ce793a526a9e24275

LABEL maintainer="Sebastien Rousseau <sebastienrousseau@users.noreply.github.com>"

COPY . "$SRC/dotfiles"
WORKDIR "$SRC/dotfiles/fuzz"
COPY .clusterfuzzlite/build.sh "$SRC/build.sh"
RUN chmod +x "$SRC/build.sh"
