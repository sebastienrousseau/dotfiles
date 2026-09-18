# OSS-Fuzz build environment for sebastienrousseau/dotfiles.
#
# Copied verbatim into google/oss-fuzz at projects/dotfiles/Dockerfile
# when the upstream PR lands.

# hadolint ignore=DL3006
FROM gcr.io/oss-fuzz-base/base-builder-go

# Maintainer (per OSS-Fuzz convention).
LABEL maintainer="Sebastien Rousseau <sebastian.rousseau@gmail.com>"

# Clone the project repo. OSS-Fuzz builders run `git clone <url> $SRC/<repo>`
# during the seed phase; ARG SRC defaults to /src.
RUN git clone --depth 1 \
    https://github.com/sebastienrousseau/dotfiles.git \
    "$SRC/dotfiles"

# Compile-time deps. The Go fuzzers in fuzz/ are self-contained (no
# external imports beyond the stdlib + the project's own packages),
# so this Dockerfile is minimal.

WORKDIR ${SRC}/dotfiles/oss-fuzz-integration/fuzz

# The build script in $SRC/dotfiles/oss-fuzz-integration/build.sh is
# invoked by OSS-Fuzz's $SRC/build.sh wrapper; we just need to make
# it executable.
COPY build.sh "$SRC/"
RUN chmod +x "$SRC/build.sh"
