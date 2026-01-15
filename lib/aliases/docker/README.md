<!-- markdownlint-disable MD033 MD041 MD043 -->

<img
  src="https://kura.pro/dotfiles/v2/images/logos/dotfiles.svg"
  alt="dotfiles logo"
  width="66"
  align="right"
/>

<!-- markdownlint-enable MD033 MD041 -->

# Dotfiles (v0.2.470)

Simply designed to fit your shell life 🐚

![Dotfiles banner][banner]

## 🅳🅾🅲🅺🅴🆁 🅰🅻🅸🅰🆂🅴🆂

This code provides a comprehensive set of aliases for Docker development
using `docker`, `docker-compose`, and Docker Swarm commands.

### Docker Core Aliases

#### Basic Commands

- `dk` - Docker shortcut
- `dkv` - Show Docker version
- `dki` - Display system-wide information
- `dkl` - Login to Docker registry
- `dklo` - Logout from Docker registry

#### Container Operations

- `dkps` - List running containers
- `dkpsa` - List all containers
- `dkr` - Run a command in new container
- `dkri` - Run interactive container
- `dkrd` - Run container in background
- `dks` - Start container
- `dkst` - Stop container
- `dkrs` - Restart container
- `dkp` - Pause container
- `dkup` - Unpause container
- `dkrm` - Remove container
- `dkrma` - Remove all containers
- `dkrmf` - Force remove container

#### Container Inspection

- `dkin` - Inspect container
- `dkl` - Show container logs
- `dklf` - Follow container logs
- `dkt` - Show running processes in container
- `dkst` - Show container resource usage
- `dkdf` - Show container filesystem changes
- `dkpl` - Pull image from registry
- `dkex` - Execute command in container
- `dkeit` - Execute interactive command

#### Images

- `dki` - List images
- `dkia` - List all images
- `dkb` - Build an image
- `dkbt` - Build and tag an image
- `dkpu` - Push image to registry
- `dkrmi` - Remove image
- `dkh` - Show image history
- `dksv` - Save image to tar archive
- `dkld` - Load image from tar archive
- `dkprune` - Remove unused data
- `dkprunea` - Remove all unused data
- `dkrmi_dangling` - Remove dangling images

#### Volumes

- `dkv` - Volume shortcut
- `dkvls` - List volumes
- `dkvc` - Create volume
- `dkvi` - Inspect volume
- `dkvrm` - Remove volume
- `dkvp` - Remove unused volumes

#### Networks

- `dkn` - Network shortcut
- `dknls` - List networks
- `dknc` - Create network
- `dkni` - Inspect network
- `dknrm` - Remove network
- `dknp` - Remove unused networks
- `dkncon` - Connect container to network
- `dkndis` - Disconnect container from network

#### System

- `dks` - System shortcut
- `dksdf` - Show Docker disk usage
- `dksev` - Get real-time events from Docker
- `dksi` - Display system-wide information
- `dksp` - Remove unused data
- `dkspa` - Remove all unused data
- `dkcon` - Context management

#### Miscellaneous

- `dkcp` - Copy files between container and local filesystem
- `dkw` - Block until container stops
- `dkk` - Kill container
- `dkatt` - Attach to container
- `dkd` - Inspect changes on container's filesystem
- `dkcom` - Create image from container
- `dktag` - Tag an image
- `dkexp` - Export container's filesystem
- `dkimp` - Import container filesystem
- `dkscan` - Scan image for vulnerabilities

### Docker Compose Aliases

- `dc` - Docker Compose shortcut
- `dcu` - Create and start containers
- `dcud` - Create and start containers in background
- `dcd` - Stop and remove containers
- `dcdv` - Stop and remove containers and volumes
- `dcr` - Restart services
- `dcs` - Stop services
- `dcsta` - Start services
- `dcp` - Pause services
- `dcup` - Unpause services
- `dcps` - List containers
- `dcl` - View logs
- `dclf` - Follow logs
- `dcex` - Execute command in container
- `dcb` - Build services
- `dcpull` - Pull service images
- `dcpush` - Push service images
- `dcrm` - Remove stopped containers
- `dcrun` - Run one-off command
- `dci` - List images
- `dck` - Kill containers
- `dccfg` - Validate and show compose config
- `dcev` - Receive events from containers
- `dctop` - Display running processes
- `dcv` - Show Docker Compose version

### Docker Swarm Aliases

#### Swarm Management

- `dksw` - Swarm shortcut
- `dkswi` - Initialize Docker Swarm
- `dkswj` - Join Docker Swarm
- `dkswjt` - Manage join tokens
- `dkswl` - Leave the Swarm
- `dkswu` - Update Swarm
- `dkswunl` - Unlock Swarm
- `dkswunk` - Manage unlock keys

#### Services

- `dksrv` - Service shortcut
- `dksrvls` - List services
- `dksrvc` - Create service
- `dksrvi` - Inspect service
- `dksrvps` - List tasks of service
- `dksrvl` - View service logs
- `dksrvlf` - Follow service logs
- `dksrvrm` - Remove service
- `dksrvsc` - Scale service
- `dksrvu` - Update service
- `dksrvrl` - Rollback service

#### Stacks

- `dkstk` - Stack shortcut
- `dkstkls` - List stacks
- `dkstkd` - Deploy stack
- `dkstkps` - List tasks in stack
- `dkstksrv` - List services in stack
- `dkstkrm` - Remove stack

#### Nodes

- `dkn` - Node shortcut
- `dknls` - List nodes
- `dkni` - Inspect node
- `dknp` - Promote node to manager
- `dknd` - Demote node to worker
- `dknrm` - Remove node
- `dknu` - Update node
- `dknps` - List tasks running on node

### Common Workflows

#### Container Development Workflow

```bash
# Start a development container
dkri --name dev-container -v $(pwd):/app -p 3000:3000 node:latest bash
```

#### Docker Compose Development

```bash
# Start services, rebuild if needed, in background
dcb && dcud
```

#### Cleanup Workflow

```bash
# Remove all stopped containers, unused networks, and dangling images
dkrm $(dk ps -aq --filter status=exited) && dknp && dkrmi_dangling
```

#### Deployment to Swarm

```bash
# Deploy or update a stack from a compose file
dkstkd -c docker-compose.yml my-stack
```

[banner]: https://kura.pro/dotfiles/v2/images/titles/title-dotfiles.svg
