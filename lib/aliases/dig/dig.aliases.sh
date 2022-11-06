#!/usr/bin/env bash
# 🅳🅾🆃🅵🅸🅻🅴🆂 (v0.2.462) - https://dotfiles.io
# Made with ♥ in London, UK by @sebastienrousseau
# Copyright (c) 2015-2022. All rights reserved
# License: MIT

# 🅳🅸🅶 🅰🅻🅸🅰🆂🅴🆂
if command -v dig &>/dev/null; then
  alias dga='$(which dig) +all ANY'                                                 # dga: Perform a DNS lookup for all records.
  alias dgs='$(which dig) +short'                                                   # dgs: Perform a DNS lookup.
  alias digg='$(which dig) @8.8.8.8 +nocmd any +multiline +noall +answer'           # digg: Dig with Google's DNS.
  alias ip4='$(which dig) +short myip.opendns.com @resolver1.opendns.com -4'        # ip4: Display the public IPv4 address.
  alias ip6='$(which dig) -6 AAAA +short myip.opendns.com. @resolver1.opendns.com.' # ip6: Get the public IPv6 address.
  alias ips='ip4; ip6'                                                              # ips: Display all IP addresses.
  alias wip='$(which dig) +short myip.opendns.com @resolver1.opendns.com'           # wip: Get public IP address.
fi
