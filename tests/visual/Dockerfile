# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
FROM node@sha256:0e0ff40c39bc087845bfb27465a0df4ea419520094bc35842ff83dd8cbe6f9b6
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates python3 python3-pil kitty tmux xvfb xauth xdotool \
    imagemagick fonts-dejavu-core fontconfig x11-utils xterm \
    && rm -rf /var/lib/apt/lists/*
ENV LIBGL_ALWAYS_SOFTWARE=1
WORKDIR /repo
ENTRYPOINT ["xvfb-run", "-a", "-s", "-screen 0 3000x1400x24", "python3", "tests/visual/capture_tmux.py"]
