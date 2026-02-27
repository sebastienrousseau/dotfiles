# shellcheck shell=bash
# Copyright (c) 2015-2026 Sebastien Rousseau. All rights reserved.
# whoisport: Function to find what is currently using a port.
whoisport() {
  port=$1
  pidInfo=$(fuser "${port}"/tcp 2>/dev/null)
  pid=$(echo "${pidInfo}" | cut -d':' -f2)
  ls -l /proc/"${pid}"/exe
}
