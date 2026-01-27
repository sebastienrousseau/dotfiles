# shellcheck shell=bash
# Network and security tool aliases

if command -v nmap &>/dev/null; then
  alias nmap-quick='nmap -T4 -F'
  alias nmap-full='nmap -T4 -A -v'
  alias nmap-udp='nmap -sU -T4'
fi

if command -v nc &>/dev/null; then
  alias nc-listen='nc -lv 4444'
  alias nc-scan='nc -vz'
fi

if command -v tcpdump &>/dev/null; then
  alias tcpdump-any='sudo tcpdump -i any -n'
  alias tcpdump-http='sudo tcpdump -i any -n -s0 -A port 80'
  alias tcpdump-https='sudo tcpdump -i any -n port 443'
fi
