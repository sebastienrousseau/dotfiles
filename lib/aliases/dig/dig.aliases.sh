#!/usr/bin/env bash
# Author: Sebastien Rousseau
# Copyright (c) 2015-2023. All rights reserved
# Description: Sets aliases for the `dig` command.
# License: MIT
# Script: dig.aliases.sh
# Version: 0.2.464
# Website: https://dotfiles.io

# 🅳🅸🅶 🅰🅻🅸🅰🆂🅴🆂
if command -v 'dig' >/dev/null; then
  # DNS lookups with dig command
  alias d='$(which dig)'            # d: Run the dig command with the default options.
  alias d4='$(which dig) +short -4' # d4: Perform a DNS lookup for an IPv4 address.
  alias d6='$(which dig) +short -6' # d6: Perform a DNS lookup for an IPv6 address.
  alias dga='$(which dig) +all ANY' # dga: Perform a DNS lookup for all records.
  alias dgs='$(which dig) +short'   # dgs: Perform a DNS lookup for a short answer.

  # DNS lookups with specific options
  alias digg='$(which dig) @8.8.8.8 +nocmd any +multiline +noall +answer' # digg: Dig with Google's DNS.

  # IP address lookups
  alias ip4='$(which dig) +short myip.opendns.com @resolver1.opendns.com -4'        # ip4: Get your public IPv4 address.
  alias ip6='$(which dig) -6 AAAA +short myip.opendns.com. @resolver1.opendns.com.' # ip6: Get your public IPv6 address.
  alias ips='ip4; ip6'                                                              # ips: Get your public IPv4 and IPv6 addresses.
  alias wip='$(which dig) +short myip.opendns.com @resolver1.opendns.com'           # wip: Get your public IP address.

  # DNS lookups for MX records
  alias dmx='$(which dig) +short -t MX' # dmx: Perform a DNS lookup for MX records.

  # DNS lookups for NS records
  alias dns='$(which dig) +short -t NS' # dns: Perform a DNS lookup for NS records.

  # DNS lookups for CNAME records
  alias dc='$(which dig) +short -t CNAME' # dc: Perform a DNS lookup for CNAME records.

  # DNS lookups for SOA records
  alias dsoa='$(which dig) +short -t SOA' # dsoa: Perform a DNS lookup for SOA records.

  # DNS lookups for TXT records
  alias dt='$(which dig) +short -t TXT' # dt: Perform a DNS lookup for TXT records.

  # DNS lookups for PTR records
  alias dptr='$(which dig) +short -x' # dptr: Perform a DNS lookup for PTR records.

fi
