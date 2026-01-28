# shellcheck shell=bash
# Copyright (c) 2015-2026. All rights reserved.
# Version: 0.2.477
# Website: https://dotfiles.io
# License: MIT

# 🅳🅸🅶 🅰🅻🅸🅰🆂🅴🆂
if command -v dig &>/dev/null; then
  # d: Run the dig command with the default options.
  if ! alias d >/dev/null 2>&1; then
    alias d='dig'
  fi

  # d4: Perform a DNS lookup for an IPv4 address.
  alias d4='dig +short -4'

  # d6: Perform a DNS lookup for an IPv6 address.
  alias d6='dig +short -6'

  # dga: Perform a DNS lookup for all records.
  alias dga='dig +all ANY'

  # dgs: Perform a DNS lookup for a short answer.
  alias dgs='dig +short'

  # digg: Dig with Google's DNS.
  alias digg='dig @8.8.8.8 +nocmd any +multiline +noall +answer'

  # ip4: Get your public IPv4 address.
  alias ip4='dig +short myip.opendns.com @resolver1.opendns.com -4'

  # ip6: Get your public IPv6 address.
  alias ip6='dig -6 AAAA +short myip.opendns.com. @resolver1.opendns.com.'

  # ips: Get your public IPv4 and IPv6 addresses.
  alias ips='ip4; ip6'

  # wip: Get your public IP address.
  alias wip='dig +short myip.opendns.com @resolver1.opendns.com'

fi
