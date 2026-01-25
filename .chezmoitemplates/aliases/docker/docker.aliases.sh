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
  alias dk='docker'
  alias dkv='docker version'
  alias dki='docker info'
  alias dkl='docker login'
  alias dklo='docker logout'

  # --- Containers ---
  alias dkps='docker ps'
  alias dps='docker ps'
  alias dpsa='docker ps -a'
  alias dkpsa='docker ps -a'
  alias dkr='docker run'
  alias dkri='docker run -it'
  alias dkrd='docker run -d'
  alias dks='docker start'
  alias dstart='docker start'
  alias dkst='docker stop'
  alias dstop='docker stop'
  alias dkrs='docker restart'
  alias drestart='docker restart'
  alias dkp='docker pause'
  alias dkup='docker unpause'
  alias dkrm='docker rm'
  alias drm='docker rm'
  alias dkrma='docker rm $(docker ps -aq) 2>/dev/null || true'
  alias drma='docker rm $(docker ps -aq) 2>/dev/null || true'
  alias dkrmf='docker rm -f'
  alias drmf='docker rm -f'

  alias dkin='docker inspect'
  alias dinspect='docker inspect'
  alias dklg='docker logs'
  alias dlogs='docker logs'
  alias dklf='docker logs -f'
  alias dlogsf='docker logs -f'
  alias dl='docker logs -f'
  alias dkt='docker top'
  alias dtop='docker top'
  alias dkst='docker stats'
  alias dstats='docker stats'
  alias dkdf='docker diff'
  alias dkpl='docker pull'
  alias dpull='docker pull'
  alias dkex='docker exec'
  alias dkeit='docker exec -it'
  alias dexec='docker exec -it'
  alias dex='docker exec -it'

  alias dkcp='docker cp'
  alias dkw='docker wait'
  alias dkk='docker kill'

  # --- Images ---
  alias dkim='docker images'
  alias dim='docker images'
  alias dkia='docker images -a'
  alias dima='docker images -a'
  alias dkb='docker build'
  alias dbuild='docker build'
  alias dkbt='docker build -t'
  alias dkpu='docker push'
  alias dpush='docker push'
  alias dkrmi='docker rmi'
  alias drmi='docker rmi'
  alias dkh='docker history'
  alias dhist='docker history'
  alias dksv='docker save'
  alias dsave='docker save'
  alias dkld='docker load'
  alias dload='docker load'
  alias dkprune='docker system prune'
  alias dprune='docker system prune'
  alias dkprunea='docker system prune -a'
  alias dprunea='docker system prune -a'
  alias dprunev='docker system prune --volumes'
  alias dpruneaf='docker system prune -af --volumes'
  alias dkrmi_dangling='docker rmi $(docker images -f "dangling=true" -q) 2>/dev/null || true'
  alias drmid='docker rmi $(docker images -f "dangling=true" -q) 2>/dev/null || true'

  # --- Volumes ---
  alias dkvl='docker volume'
  alias dvol='docker volume'
  alias dkvls='docker volume ls'
  alias dvolls='docker volume ls'
  alias dkvc='docker volume create'
  alias dvolcreate='docker volume create'
  alias dkvi='docker volume inspect'
  alias dvolinspect='docker volume inspect'
  alias dkvrm='docker volume rm'
  alias dvolrm='docker volume rm'
  alias dkvp='docker volume prune'
  alias dvprune='docker volume prune -f'

  # --- Networks ---
  alias dkn='docker network'
  alias dnet='docker network'
  alias dknls='docker network ls'
  alias dnetls='docker network ls'
  alias dknc='docker network create'
  alias dnetcreate='docker network create'
  alias dkni='docker network inspect'
  alias dnetinspect='docker network inspect'
  alias dknrm='docker network rm'
  alias dnetrm='docker network rm'
  alias dknp='docker network prune'
  alias dnprune='docker network prune -f'
  alias dkncon='docker network connect'
  alias dkndis='docker network disconnect'

  # --- System ---
  alias dksys='docker system'
  alias dksdf='docker system df'
  alias ddf='docker system df'
  alias ddfv='docker system df -v'
  alias dksev='docker system events'
  alias devents='docker system events'
  alias dksi='docker system info'
  alias dksp='docker system prune'
  alias dkspa='docker system prune -a'
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
  alias dcupb='docker compose up --build'
  alias dcupd='docker compose up -d'
  alias dcupdb='docker compose up -d --build'
  alias dcdown='docker compose down'
  alias dcdownv='docker compose down -v'
fi

# --- Docker Compose (legacy docker-compose) ---
if command -v 'docker-compose' &>/dev/null; then
  alias dc='docker-compose'
  alias dcu='docker-compose up'
  alias dcud='docker-compose up -d'
  alias dcd='docker-compose down'
  alias dcdv='docker-compose down -v'
  alias dcrs='docker-compose restart'
  alias dcs='docker-compose stop'
  alias dcsta='docker-compose start'
  alias dcex='docker-compose exec'
  alias dcbuild='docker-compose build'
  alias dcpush='docker-compose push'
  alias dcrun='docker-compose run'
  alias dci='docker-compose images'
  alias dck='docker-compose kill'
  alias dccfg='docker-compose config'
  alias dctop='docker-compose top'
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
