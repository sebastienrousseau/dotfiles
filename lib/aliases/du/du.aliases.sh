#!/usr/bin/env bash
# Author: Sebastien Rousseau
# Copyright (c) 2015-2023. All rights reserved
# Description: Sets Disk Usage Aliases
# License: MIT
# Script: du.aliases.sh
# Version: 0.2.463
# Website: https://dotfiles.io

# 🅳🅸🆂🅺 🆄🆂🅰🅶🅴 🅰🅻🅸🅰🆂🅴🆂
if command -v 'du' >/dev/null; then
  # Disk usage aliases
  alias du="du -h"                                   # du: Display the disk usage of the current directory.
  alias du1='du -hxd 1 | sort -h'                    # du1: File size of files and directories in current directory.
  alias ducks="du -cks * .* | sort -rn | head -n 10" # ducks: Top 10 largest files and directories in current directory.
  alias duh='du'                                     # duh: File size of files and directories.
  alias dus='du -hs *'                               # dus: File size human readable output sorted by size.
  alias dusym="du * -hsLc"                           # dusym: File size of files and directories in current directory including symlinks.
  alias dut='dus'                                    # dut: Total file size of current directory.

  # DNS aliases
  alias d='$(which dig)'                                                            # d: Run the dig command with the default options.
  alias dc='$(which dig) +short -t CNAME'                                           # dc: Perform a DNS lookup for CNAME records.
  alias dga='$(which dig) +all ANY'                                                 # dga: Perform a DNS lookup for all records.
  alias digg='$(which dig) @8.8.8.8 +nocmd any +multiline +noall +answer'           # digg: Dig with Google's DNS.
  alias dgs='$(which dig) +short'                                                   # dgs: Perform a DNS lookup for a short answer.
  alias dns='$(which dig) +short -t NS'                                             # dns: Perform a DNS lookup for NS records.
  alias dmx='$(which dig) +short -t MX'                                             # dmx: Perform a DNS lookup for MX records.
  alias dptr='$(which dig) +short -x'                                               # dptr: Perform a DNS lookup for PTR records.
  alias dt='$(which dig) +short -t TXT'                                             # dt: Perform a DNS lookup for TXT records.
  alias d4='$(which dig) +short -4'                                                 # d4: Perform a DNS lookup for an IPv4 address.
  alias d6='$(which dig) +short -6'                                                 # d6: Perform a DNS lookup for an IPv6 address.
  alias ip4='$(which dig) +short myip.opendns.com @resolver1.opendns.com -4'        # ip4: Get your public IPv4 address.
  alias ip6='$(which dig) -6 AAAA +short myip.opendns.com. @resolver1.opendns.com.' # ip6: Get your public IPv6 address.
  alias ips='ip4; ip6'                                                              # ips: Get your public IPv4 and IPv6 addresses.
  alias wip='$(which dig) +short myip.opendns.com @resolver1.opendns.com'           # wip: Get your public IP address.
fi
