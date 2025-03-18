#!/usr/bin/env bash
# 🅳🅾🆃🅵🅸🅻🅴🆂 (v0.2.470) - <https://dotfiles.io>
# Made with ♥ in London, UK by Sebastien Rousseau
# Copyright (c) 2015-2025. All rights reserved
# License: MIT

# 🅳🅾🅲🅺🅴🆁 🅰🅻🅸🅰🆂🅴🆂
if command -v 'docker' >/dev/null; then
    # Basic Commands
    alias dk='docker'                           # Docker shortcut
    alias dkv='dk version'                      # Show Docker version
    alias dki='dk info'                         # Display system-wide information
    alias dkl='dk login'                        # Login to Docker registry
    alias dklo='dk logout'                      # Logout from Docker registry

    # Container Operations
    alias dkps='dk ps'                          # List running containers
    alias dkpsa='dk ps -a'                      # List all containers
    alias dkr='dk run'                          # Run a command in new container
    alias dkri='dk run -it'                     # Run interactive container
    alias dkrd='dk run -d'                      # Run container in background
    alias dks='dk start'                        # Start container
    alias dkst='dk stop'                        # Stop container
    alias dkrs='dk restart'                     # Restart container
    alias dkp='dk pause'                        # Pause container
    alias dkup='dk unpause'                     # Unpause container
    alias dkrm='dk rm'                          # Remove container
    alias dkrma='dk rm $(dk ps -aq)'            # Remove all containers
    alias dkrmf='dk rm -f'                      # Force remove container

    # Container Inspection
    alias dkin='dk inspect'                     # Inspect container
    alias dkl='dk logs'                         # Show container logs
    alias dklf='dk logs -f'                     # Follow container logs
    alias dkt='dk top'                          # Show running processes in container
    alias dkst='dk stats'                       # Show container resource usage
    alias dkdf='dk diff'                        # Show container filesystem changes
    alias dkpl='dk pull'                        # Pull image from registry
    alias dkex='dk exec'                        # Execute command in container
    alias dkeit='dk exec -it'                   # Execute interactive command

    # Images
    alias dki='dk images'                       # List images
    alias dkia='dk images -a'                   # List all images
    alias dkb='dk build'                        # Build an image
    alias dkbt='dk build -t'                    # Build and tag an image
    alias dkpu='dk push'                        # Push image to registry
    alias dkrmi='dk rmi'                        # Remove image
    alias dkh='dk history'                      # Show image history
    alias dksv='dk save'                        # Save image to tar archive
    alias dkld='dk load'                        # Load image from tar archive
    alias dkprune='dk system prune'             # Remove unused data
    alias dkprunea='dk system prune -a'         # Remove all unused data
    alias dkrmi_dangling='dk rmi $(dk images -f "dangling=true" -q)' # Remove dangling images

    # Volumes
    alias dkv='dk volume'                       # Volume shortcut
    alias dkvls='dk volume ls'                  # List volumes
    alias dkvc='dk volume create'               # Create volume
    alias dkvi='dk volume inspect'              # Inspect volume
    alias dkvrm='dk volume rm'                  # Remove volume
    alias dkvp='dk volume prune'                # Remove unused volumes

    # Networks
    alias dkn='dk network'                      # Network shortcut
    alias dknls='dk network ls'                 # List networks
    alias dknc='dk network create'              # Create network
    alias dkni='dk network inspect'             # Inspect network
    alias dknrm='dk network rm'                 # Remove network
    alias dknp='dk network prune'               # Remove unused networks
    alias dkncon='dk network connect'           # Connect container to network
    alias dkndis='dk network disconnect'        # Disconnect container from network

    # System
    alias dks='dk system'                       # System shortcut
    alias dksdf='dk system df'                  # Show Docker disk usage
    alias dksev='dk system events'              # Get real-time events from Docker
    alias dksi='dk system info'                 # Display system-wide information
    alias dksp='dk system prune'                # Remove unused data
    alias dkspa='dk system prune -a'            # Remove all unused data
    alias dkcon='dk context'                    # Context management

    # Miscellaneous
    alias dkcp='dk cp'                          # Copy files between container and local filesystem
    alias dkw='dk wait'                         # Block until container stops
    alias dkk='dk kill'                         # Kill container
    alias dkatt='dk attach'                     # Attach to container
    alias dkd='dk diff'                         # Inspect changes on container's filesystem
    alias dkcom='dk commit'                     # Create image from container
    alias dktag='dk tag'                        # Tag an image
    alias dkexp='dk export'                     # Export container's filesystem
    alias dkimp='dk import'                     # Import container filesystem
    alias dkscan='dk scan'                      # Scan image for vulnerabilities
fi

# 🅳🅾🅲🅺🅴🆁 🅲🅾🅼🅿🅾🆂🅴 🅰🅻🅸🅰🆂🅴🆂
if command -v 'docker-compose' >/dev/null; then
    alias dc='docker-compose'                   # Docker Compose shortcut
    alias dcu='dc up'                           # Create and start containers
    alias dcud='dc up -d'                       # Create and start containers in background
    alias dcd='dc down'                         # Stop and remove containers
    alias dcdv='dc down -v'                     # Stop and remove containers and volumes
    alias dcr='dc restart'                      # Restart services
    alias dcs='dc stop'                         # Stop services
    alias dcsta='dc start'                      # Start services
    alias dcp='dc pause'                        # Pause services
    alias dcup='dc unpause'                     # Unpause services
    alias dcps='dc ps'                          # List containers
    alias dcl='dc logs'                         # View logs
    alias dclf='dc logs -f'                     # Follow logs
    alias dcex='dc exec'                        # Execute command in container
    alias dcb='dc build'                        # Build services
    alias dcpull='dc pull'                      # Pull service images
    alias dcpush='dc push'                      # Push service images
    alias dcrm='dc rm'                          # Remove stopped containers
    alias dcrun='dc run'                        # Run one-off command
    alias dci='dc images'                       # List images
    alias dck='dc kill'                         # Kill containers
    alias dccfg='dc config'                     # Validate and show compose config
    alias dcev='dc events'                      # Receive events from containers
    alias dctop='dc top'                        # Display running processes
    alias dcv='dc version'                      # Show Docker Compose version
fi

# 🅳🅾🅲🅺🅴🆁 🆂🆆🅰🆁🅼 🅰🅻🅸🅰🆂🅴🆂
if command -v 'docker' >/dev/null && dk swarm 2>/dev/null; then
    alias dksw='dk swarm'                       # Swarm shortcut
    alias dkswi='dk swarm init'                 # Initialize Docker Swarm
    alias dkswj='dk swarm join'                 # Join Docker Swarm
    alias dkswjt='dk swarm join-token'          # Manage join tokens
    alias dkswl='dk swarm leave'                # Leave the Swarm
    alias dkswu='dk swarm update'               # Update Swarm
    alias dkswunl='dk swarm unlock'             # Unlock Swarm
    alias dkswunk='dk swarm unlock-key'         # Manage unlock keys

    # Services
    alias dksrv='dk service'                    # Service shortcut
    alias dksrvls='dk service ls'               # List services
    alias dksrvc='dk service create'            # Create service
    alias dksrvi='dk service inspect'           # Inspect service
    alias dksrvps='dk service ps'               # List tasks of service
    alias dksrvl='dk service logs'              # View service logs
    alias dksrvlf='dk service logs -f'          # Follow service logs
    alias dksrvrm='dk service rm'               # Remove service
    alias dksrvsc='dk service scale'            # Scale service
    alias dksrvu='dk service update'            # Update service
    alias dksrvrl='dk service rollback'         # Rollback service

    # Stacks
    alias dkstk='dk stack'                      # Stack shortcut
    alias dkstkls='dk stack ls'                 # List stacks
    alias dkstkd='dk stack deploy'              # Deploy stack
    alias dkstkps='dk stack ps'                 # List tasks in stack
    alias dkstksrv='dk stack services'          # List services in stack
    alias dkstkrm='dk stack rm'                 # Remove stack

    # Nodes
    alias dkn='dk node'                         # Node shortcut
    alias dknls='dk node ls'                    # List nodes
    alias dkni='dk node inspect'                # Inspect node
    alias dknp='dk node promote'                # Promote node to manager
    alias dknd='dk node demote'                 # Demote node to worker
    alias dknrm='dk node rm'                    # Remove node
    alias dknu='dk node update'                 # Update node
    alias dknps='dk node ps'                    # List tasks running on node
fi
