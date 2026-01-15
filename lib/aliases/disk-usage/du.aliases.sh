#!/usr/bin/env bash

# Author: Sebastien Rousseau
# Copyright (c) 2015-2025. All rights reserved
# Description: Sets Disk Usage Aliases
# License: MIT
# Script: du.aliases.sh
# Version: 0.2.470
# Website: https://dotfiles.io

# 🅳🅸🆂🅺 🆄🆂🅰🅶🅴 🅰🅻🅸🅰🆂🅴🆂

if command -v 'du' >/dev/null; then

  # Display the disk usage of the current directory.
  alias du="du -h"

  # File size of files and directories in current directory.
  alias du1='du -hxd 1 | sort -h'

  # Top 10 largest files and directories in current directory.
  alias ducks="du -cks * .* | sort -rn | head -n 10"

  # File size of files and directories.
  alias duh='du'

  # File size human readable output sorted by size.
  alias dus='du -hs *'

  # File size of files and directories in current directory including
  # symlinks.
  alias dusym="du * -hsLc"

  # Total file size of current directory.
  alias dut='dus'

  # DNS aliases

  # Run the dig command with the default options.
  alias d='$(which dig)'

  # Perform a DNS lookup for CNAME records.
  alias dc='$(which dig) +short -t CNAME'

  # Perform a DNS lookup for all records.
  alias dga='$(which dig) +all ANY'

  # Dig with Google's DNS.
  alias digg='$(which dig) @8.8.8.8 +nocmd any +multiline +noall +answer'

  # Perform a DNS lookup for a short answer.
  alias dgs='$(which dig) +short'

  # Perform a DNS lookup for NS records.
  alias dns='$(which dig) +short -t NS'

  # Perform a DNS lookup for MX records.
  alias dmx='$(which dig) +short -t MX'

  # Perform a DNS lookup for PTR records.
  alias dptr='$(which dig) +short -x'

  # Perform a DNS lookup for TXT records.
  alias dt='$(which dig) +short -t TXT'

  # Perform a DNS lookup for an IPv4 address.
  alias d4='$(which dig) +short -4'

  # Perform a DNS lookup for an IPv6 address.
  alias d6='$(which dig) +short -6'

  # Get your public IPv4 address.
  alias ip4='$(which dig) +short myip.opendns.com @resolver1.opendns.com -4'

  # Get your public IPv6 address.
  alias ip6='$(which dig) -6 AAAA +short myip.opendns.com. @resolver1.opendns.com.'

  # Get your public IPv4 and IPv6 addresses.
  alias ips='ip4; ip6'

  # Get your public IP address.
  alias wip='$(which dig) +short myip.opendns.com @resolver1.opendns.com'

fi
