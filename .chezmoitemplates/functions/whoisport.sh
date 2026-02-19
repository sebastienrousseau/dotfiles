# shellcheck shell=bash
# whoisport: Function to find what is currently using a port.
whoisport() {
  port=$1
  pidInfo=$(fuser "${port}"/tcp 2>/dev/null)
  pid=$(echo "${pidInfo}" | cut -d':' -f2)
  ls -l /proc/"${pid}"/exe
}
