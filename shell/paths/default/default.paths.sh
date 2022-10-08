#!/usr/bin/env bash
# 🅳🅾🆃🅵🅸🅻🅴🆂 (v0.2.456) - https://dotfiles.io
# Copyright (c) Sebastien Rousseau 2022. All rights reserved
# License: MIT

## 🅿🅰🆃🅷🆂

### Add 'PATH' entries.
export PATH=/usr/local/bin:"${PATH}"        # Add /usr/local/bin to the path
export PATH=/usr/local/sbin:"${PATH}"       # Add /usr/local/sbin to the path
export PATH=/usr/bin:"${PATH}"              # Add /usr/bin to the path
export PATH=/bin:"${PATH}"                  # Add /bin to the path
export PATH=/usr/sbin:"${PATH}"             # Add /usr/sbin to the path
export PATH=/sbin:"${PATH}"                 # Add /sbin to the path
export PATH="${HOME}"/.cargo/bin:"${PATH}"  # Add ~/.cargo/bin to the path
export PATH="${HOME}"/.yarn/bin:"${PATH}"   # Add ~/.yarn/bin to the path
export PATH="${HOME}"/go/bin:"${PATH}"      # Add ~/go/bin to the path
