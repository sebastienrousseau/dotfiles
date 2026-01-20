# Docker Aliases
#
# Sections:
# 1. Core & Containers
# 2. Images
# 3. Volumes & Networks
# 4. System & Context
# 5. Compose
# 6. Swarm

if command -v 'docker' &>/dev/null; then
  
  # --- Core ---
  alias dk='docker'
  alias dkv='docker version'
  alias dki='docker info'
  alias dkl='docker login'
  alias dklo='docker logout'

  # --- Containers ---
  alias dkps='docker ps'
  alias dkpsa='docker ps -a'
  alias dkr='docker run'
  alias dkri='docker run -it'
  alias dkrd='docker run -d'
  alias dks='docker start'
  alias dkst='docker stop'
  alias dkrs='docker restart'
  alias dkp='docker pause'
  alias dkup='docker unpause'
  alias dkrm='docker rm'
  alias dkrma='docker rm $(docker ps -aq)'
  alias dkrmf='docker rm -f'
  
  alias dkin='docker inspect'
  alias dklg='docker logs'
  alias dklf='docker logs -f'
  alias dkt='docker top'
  alias dkst='docker stats'
  alias dkdf='docker diff'
  alias dkpl='docker pull'
  alias dkex='docker exec'
  alias dkeit='docker exec -it'
  
  alias dkcp='docker cp'
  alias dkw='docker wait'
  alias dkk='docker kill'
  
  # --- Images ---
  alias dkim='docker images' # renamed from dki to avoid conflict
  alias dkia='docker images -a'
  alias dkb='docker build'
  alias dkbt='docker build -t'
  alias dkpu='docker push'
  alias dkrmi='docker rmi'
  alias dkh='docker history'
  alias dksv='docker save'
  alias dkld='docker load'
  alias dkprune='docker system prune'
  alias dkprunea='docker system prune -a'
  alias dkrmi_dangling='docker rmi $(docker images -f "dangling=true" -q)'

  # --- Volumes ---
  alias dkvl='docker volume' # renamed from dkv to avoid conflict
  alias dkvls='docker volume ls'
  alias dkvc='docker volume create'
  alias dkvi='docker volume inspect'
  alias dkvrm='docker volume rm'
  alias dkvp='docker volume prune'

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
  alias dksys='docker system' # renamed from dks to avoid conflict
  alias dksdf='docker system df'
  alias dksev='docker system events'
  alias dksi='docker system info'
  alias dksp='docker system prune'
  alias dkspa='docker system prune -a'
  alias dkcon='docker context'
fi

# --- Docker Compose ---
if command -v 'docker-compose' &>/dev/null; then
  alias dc='docker-compose'
  alias dcu='docker-compose up'
  alias dcud='docker-compose up -d'
  alias dcd='docker-compose down'
  alias dcdv='docker-compose down -v'
  alias dcr='docker-compose restart'
  alias dcs='docker-compose stop'
  alias dcsta='docker-compose start'
  alias dcps='docker-compose ps'
  alias dcl='docker-compose logs'
  alias dclf='docker-compose logs -f'
  alias dcex='docker-compose exec'
  alias dcb='docker-compose build'
  alias dcpull='docker-compose pull'
  alias dcpush='docker-compose push'
  alias dcrm='docker-compose rm'
  alias dcrun='docker-compose run'
  alias dci='docker-compose images'
  alias dck='docker-compose kill'
  alias dccfg='docker-compose config'
  alias dctop='docker-compose top'
fi

# --- Docker Swarm ---
if command -v 'docker' &>/dev/null && docker swarm &>/dev/null; then
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
  
  alias dknode='docker node' # renamed from dkn to avoid conflict
  alias dknls='docker node ls'
  alias dkni='docker node inspect'
fi
