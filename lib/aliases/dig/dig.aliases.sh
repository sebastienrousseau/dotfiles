#!/usr/bin/env bash
# 🅳🅾🆃🅵🅸🅻🅴🆂 (v0.2.462) - https://dotfiles.io
# Made with ♥ in London, UK by @sebastienrousseau
# Copyright (c) 2015-2022. All rights reserved
# License: MIT

# 🅳🅸🅶 🅰🅻🅸🅰🆂🅴🆂
if command -v dig &>/dev/null; then
  alias d='$(which dig)'                                                            # d: Run the dig command with the default options.
  alias d4='$(which dig) +short -4'                                                 # d4: Perform a DNS lookup for an IPv4 address.
  alias d6='$(which dig) +short -6'                                                 # d6: Perform a DNS lookup for an IPv6 address.
  alias dga='$(which dig) +all ANY'                                                 # dga: Perform a DNS lookup for all records.
  alias dgs='$(which dig) +short'                                                   # dgs: Perform a DNS lookup for a short answer.
  alias digg='$(which dig) @8.8.8.8 +nocmd any +multiline +noall +answer'           # digg: Dig with Google's DNS.
  alias ip4='$(which dig) +short myip.opendns.com @resolver1.opendns.com -4'        # ip4: Get your public IPv4 address.
  alias ip6='$(which dig) -6 AAAA +short myip.opendns.com. @resolver1.opendns.com.' # ip6: Get your public IPv6 address.
  alias ips='ip4; ip6'                                                              # ips: Get your public IPv4 and IPv6 addresses.
  alias wip='$(which dig) +short myip.opendns.com @resolver1.opendns.com'           # wip: Get your public IP address.
fi
