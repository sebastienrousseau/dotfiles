#!/usr/bin/env bash

# 🅳🅾🆃🅵🅸🅻🅴🆂 (v0.2.470) - <https://dotfiles.io>
# Made with ♥ in London, UK by Sebastien Rousseau
# Copyright (c) 2015-2025. All rights reserved
# License: MIT
# Script: dig.aliases.sh
# Version: 0.2.470
# Website: https://dotfiles.io

# 🅳🅸🅶 🅰🅻🅸🅰🆂🅴🆂
if command -v dig &>/dev/null; then
  # d: Run the dig command with the default options.
  alias d='$(which dig)'

  # d4: Perform a DNS lookup for an IPv4 address.
  alias d4='$(which dig) +short -4'

  # d6: Perform a DNS lookup for an IPv6 address.
  alias d6='$(which dig) +short -6'

  # dga: Perform a DNS lookup for all records.
  alias dga='$(which dig) +all ANY'

  # dgs: Perform a DNS lookup for a short answer.
  alias dgs='$(which dig) +short'

  # digg: Dig with Google's DNS.
  alias digg='$(which dig) @8.8.8.8 +nocmd any +multiline +noall +answer'

  # ip4: Get your public IPv4 address.
  alias ip4='$(which dig) +short myip.opendns.com @resolver1.opendns.com -4'

  # ip6: Get your public IPv6 address.
  alias ip6='$(which dig) -6 AAAA +short myip.opendns.com. @resolver1.opendns.com.'

  # ips: Get your public IPv4 and IPv6 addresses.
  alias ips='ip4; ip6'

  # wip: Get your public IP address.
  alias wip='$(which dig) +short myip.opendns.com @resolver1.opendns.com'

fi
