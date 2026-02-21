# shellcheck shell=bash
# Docker Aliases
#
# Sections:
# 1. Core & Containers
# 2. Images
# 3. Volumes & Networks
# 4. System & Context
# 5. Compose (docker compose)
# 6. Buildx
# 7. Swarm
# 8. Tools (lazydocker, dive, hadolint)

if command -v 'docker' &>/dev/null; then

  # --- Core ---
  alias d='docker'
  alias dkv='docker version'
  alias dki='docker info'
  alias dkl='docker login'
  alias dklo='docker logout'

  # --- Containers ---
  alias dkps='docker ps'
  alias dps='docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"'
  alias dkpsa='docker ps -a'
  alias dkr='docker run'
  alias dkri='docker run -it'
  alias dkrd='docker run -d'
  alias dks='docker start'
  alias dkstop='docker stop'
  alias dkrs='docker restart'
  alias dkp='docker pause'
  alias dkup='docker unpause'
  alias dkrm='docker rm'
  alias dkrmf='docker rm -f'

  alias dkin='docker inspect'
  alias dklf='docker logs -f'
  alias dkt='docker top'
  alias dkst='docker stats'
  alias dkdf='docker diff'
  alias dkpl='docker pull'
  alias dex='docker exec -it'

  alias dkcp='docker cp'
  alias dkw='docker wait'
  alias dkk='docker kill'

  # --- Images ---
  alias dkim='docker images'
  alias dkima='docker images -a'
  alias dkb='docker build'
  alias dkbt='docker build -t'
  alias dkpu='docker push'
  alias dkrmi='docker rmi'
  alias dkh='docker history'
  alias dksv='docker save'
  alias dkld='docker load'
  alias dksp='docker system prune'
  dpruneaf() {
    dot_confirm_destructive "docker system prune -af --volumes" || return 1
    docker system prune -af --volumes
  }

  # --- Volumes ---
  alias dkvl='docker volume'
  alias dkvls='docker volume ls'
  alias dkvc='docker volume create'
  alias dkvi='docker volume inspect'
  alias dkvrm='docker volume rm'
  alias dkvp='docker volume prune'
  alias dvprune='docker volume prune -f'

  # --- Networks ---
  alias dkn='docker network'
  alias dknls='docker network ls'
  alias dknc='docker network create'
  alias dkni='docker network inspect'
  alias dknrm='docker network rm'
  alias dknp='docker network prune'
  alias dkncon='docker network connect'
  alias dkndis='docker network disconnect'

  # --- System ---
  alias dksys='docker system'
  alias dksdf='docker system df'
  alias ddfv='docker system df -v'
  alias dksev='docker system events'
  alias dksi='docker system info'
  alias dkcon='docker context'

  # Individual cleanup
  alias dcprune='docker container prune -f'
  alias diprune='docker image prune -f'
  alias dbprune='docker builder prune -f'

  # --- Buildx ---
  alias dbx='docker buildx'
  alias dbxb='docker buildx build'
  alias dbxbp='docker buildx build --push'
  alias dbxls='docker buildx ls'
  alias dbxuse='docker buildx use'
  alias dbxcreate='docker buildx create'
  alias dbxinspect='docker buildx inspect'
  alias dbxrm='docker buildx rm'
  alias dbxstop='docker buildx stop'
  alias dbxmulti='docker buildx build --platform linux/amd64,linux/arm64'

  # --- Convenience Functions ---
  # Stop all running containers
  dstopall() {
    local containers
    containers=$(docker ps -q)
    if [[ -n "$containers" ]]; then
      echo "Stopping all containers..."
      # shellcheck disable=SC2086
      docker stop $containers
    else
      echo "No running containers."
    fi
  }

  # Remove all containers (including running)
  drmall() {
    dot_confirm_destructive "docker rm -f all containers" || return 1
    local containers
    containers=$(docker ps -aq)
    if [[ -n "$containers" ]]; then
      echo "Removing all containers..."
      # shellcheck disable=SC2086
      docker rm -f $containers
    else
      echo "No containers to remove."
    fi
  }

  # Remove all images
  drmiall() {
    dot_confirm_destructive "docker rmi -f all images" || return 1
    local images
    images=$(docker images -q)
    if [[ -n "$images" ]]; then
      echo "Removing all images..."
      # shellcheck disable=SC2086
      docker rmi -f $images
    else
      echo "No images to remove."
    fi
  }

  # Quick shell into container
  denter() {
    local container="${1:-}"
    local shell="${2:-/bin/sh}"
    if [[ -z "$container" ]]; then
      echo "Usage: denter <container> [shell]"
      return 1
    fi
    docker exec -it "$container" "$shell"
  }

  # Get container IP address
  dip() {
    local container="${1:-}"
    if [[ -z "$container" ]]; then
      echo "Usage: dip <container>"
      return 1
    fi
    docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' "$container"
  }

  # List container ports
  dports() {
    local container="${1:-}"
    if [[ -z "$container" ]]; then
      docker ps --format "table {{.Names}}\t{{.Ports}}"
    else
      docker port "$container"
    fi
  }
fi

# --- Docker Compose (modern syntax) ---
if command -v 'docker' &>/dev/null; then
  alias dco='docker compose'
  alias dcb='docker compose build'
  alias dce='docker compose exec'
  alias dcl='docker compose logs'
  alias dclf='docker compose logs -f'
  alias dcps='docker compose ps'
  alias dcpull='docker compose pull'
  alias dcr='docker compose run'
  alias dcrestart='docker compose restart'
  alias dcrm='docker compose rm'
  alias dcstop='docker compose stop'
  alias dcup='docker compose up'
  alias dcupd='docker compose up -d'
  alias dcupb='docker compose up -d --build'
  alias dcdn='docker compose down'
  alias dcdownv='docker compose down -v'
fi

# --- Docker Swarm ---
if command -v 'docker' &>/dev/null && docker swarm &>/dev/null 2>&1; then
  alias dksw='docker swarm'
  alias dkswi='docker swarm init'
  alias dkswj='docker swarm join'
  alias dkswl='docker swarm leave'
  alias dkswu='docker swarm update'

  alias dksrv='docker service'
  alias dksrvls='docker service ls'
  alias dksrvc='docker service create'
  alias dksrvi='docker service inspect'
  alias dksrvps='docker service ps'
  alias dksrvl='docker service logs'
  alias dksrvu='docker service update'
  alias dksrvu-force='docker service update --force'
  alias dksrvrm='docker service rm'

  alias dkstk='docker stack'
  alias dkstkls='docker stack ls'
  alias dkstkd='docker stack deploy'
  alias dkstkrm='docker stack rm'
  alias dkstkps='docker stack ps'

  alias dknode='docker node'
  alias dknodels='docker node ls'
  alias dknodei='docker node inspect'
fi

# --- Lazydocker (TUI for Docker) ---
if command -v lazydocker &>/dev/null; then
  alias lzd='lazydocker'
fi

# --- Dive (Image Analysis) ---
if command -v dive &>/dev/null; then
  alias ddive='dive'
fi

# --- Hadolint (Dockerfile Linting) ---
if command -v hadolint &>/dev/null; then
  alias dlint='hadolint'
  alias dflint='hadolint Dockerfile'
fi
