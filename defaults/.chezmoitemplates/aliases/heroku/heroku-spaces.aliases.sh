# shellcheck shell=bash
# Heroku Spaces aliases
[[ -n "${_HEROKU_SPACES_LOADED:-}" ]] && return 0
_HEROKU_SPACES_LOADED=1

# hksp: List available spaces.
alias hksp='heroku spaces'

# hkspc: Create a new space.
alias hkspc='heroku spaces:create'

# hkspd: Destroy a space.
alias hkspd='heroku spaces:destroy'

# hkspi: Show info about a space.
alias hkspi='heroku spaces:info'

# hksppi: Display the information necessary to initiate a peering connection.
alias hksppi='heroku spaces:peering:info'

# hkspp: List peering connections for a space.
alias hkspp='heroku spaces:peerings'

# hksppa: Accepts a pending peering request for a private space.
alias hksppa='heroku spaces:peerings:accept'

# hksppd: Destroys an active peering connection in a private space.
alias hksppd='heroku spaces:peerings:destroy'

# hkspps: List dynos for a space.
alias hkspps='heroku spaces:ps'

# hkspr: Renames a space.
alias hkspr='heroku spaces:rename'

# hksptop: Show space topology.
alias hksptop='heroku spaces:topology'

# hkspt: Transfer a space to another team.
alias hkspt='heroku spaces:transfer'

# hkspconf: Display the configuration information for VPN.
alias hkspconf='heroku spaces:vpn:config'

# hkspvc: Create VPN.
alias hkspvc='heroku spaces:vpn:connect'

# hkspvcs: List the VPN Connections for a space.
alias hkspvcs='heroku spaces:vpn:connections'

# hkspvk: Destroys VPN in a private space.
alias hkspvk='heroku spaces:vpn:destroy'

# hkspvi: Display the information for VPN.
alias hkspvi='heroku spaces:vpn:info'

# hkspvu: Update VPN.
alias hkspvu='heroku spaces:vpn:update'

# hkspvw: Wait for VPN Connection to be created.
alias hkspvw='heroku spaces:vpn:wait'

# hkspw: Wait for a space to be created.
alias hkspw='heroku spaces:wait'
