# Docker Aliases

Manage Docker aliases. Part of the **Universal Dotfiles** configuration.

![Dotfiles banner][banner]

## Description

These aliases are defined in `docker.aliases.sh`. Loaded by the lazy alias layer `~/.config/shell/91-ux-aliases-lazy.sh`. It loads after the eager layer (zsh defers it until after startup), so its definitions replace any eager alias of the same name. Skipped when `DOTFILES_ALIAS_PROFILE=minimal` at `chezmoi apply` time.

## Aliases

| Name | Definition | Notes |
| --- | --- | --- |
| `d` | `docker` | Only when `docker` is on PATH. Replaces `d='dot'` from `system.aliases.sh` (eager layer). |
| `dkv` | `docker version` | Only when `docker` is on PATH. |
| `dki` | `docker info` | Only when `docker` is on PATH. Replaces `dki='dot ai kiro'` from `ai.aliases.sh`, which loads earlier. |
| `dkl` | `docker login` | Only when `docker` is on PATH. |
| `dklo` | `docker logout` | Only when `docker` is on PATH. |
| `dkps` | `docker ps` | Only when `docker` is on PATH. |
| `dps` | `docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"` | Only when `docker` is on PATH. |
| `dkpsa` | `docker ps -a` | Only when `docker` is on PATH. |
| `dkr` | `docker run` | Only when `docker` is on PATH. |
| `dkri` | `docker run -it` | Only when `docker` is on PATH. |
| `dkrd` | `docker run -d` | Only when `docker` is on PATH. |
| `dks` | `docker start` | Only when `docker` is on PATH. |
| `dkstop` | `docker stop` | Only when `docker` is on PATH. |
| `dkrs` | `docker restart` | Only when `docker` is on PATH. |
| `dkp` | `docker pause` | Only when `docker` is on PATH. |
| `dkup` | `docker unpause` | Only when `docker` is on PATH. |
| `dkrm` | `docker rm` | Only when `docker` is on PATH. |
| `dkrmf` | `docker rm -f` | Only when `docker` is on PATH. |
| `dkin` | `docker inspect` | Only when `docker` is on PATH. |
| `dklf` | `docker logs -f` | Only when `docker` is on PATH. |
| `dkt` | `docker top` | Only when `docker` is on PATH. |
| `dkst` | `docker stats` | Only when `docker` is on PATH. |
| `dkdf` | `docker diff` | Only when `docker` is on PATH. |
| `dkpl` | `docker pull` | Only when `docker` is on PATH. |
| `dex` | `docker exec -it` | Only when `docker` is on PATH. |
| `dkcp` | `docker cp` | Only when `docker` is on PATH. |
| `dkw` | `docker wait` | Only when `docker` is on PATH. |
| `dkk` | `docker kill` | Only when `docker` is on PATH. |
| `dkim` | `docker images` | Only when `docker` is on PATH. |
| `dkima` | `docker images -a` | Only when `docker` is on PATH. |
| `dkb` | `docker build` | Only when `docker` is on PATH. |
| `dkbt` | `docker build -t` | Only when `docker` is on PATH. |
| `dkpu` | `docker push` | Only when `docker` is on PATH. |
| `dkrmi` | `docker rmi` | Only when `docker` is on PATH. |
| `dkh` | `docker history` | Only when `docker` is on PATH. |
| `dksv` | `docker save` | Only when `docker` is on PATH. |
| `dkld` | `docker load` | Only when `docker` is on PATH. |
| `dksp` | `docker system prune` | Only when `docker` is on PATH. |
| `dpruneaf` | function | Only when `docker` is on PATH. |
| `dkvl` | `docker volume` | Only when `docker` is on PATH. |
| `dkvls` | `docker volume ls` | Only when `docker` is on PATH. |
| `dkvc` | `docker volume create` | Only when `docker` is on PATH. |
| `dkvi` | `docker volume inspect` | Only when `docker` is on PATH. |
| `dkvrm` | `docker volume rm` | Only when `docker` is on PATH. |
| `dkvp` | `docker volume prune` | Only when `docker` is on PATH. |
| `dvprune` | `docker volume prune -f` | Only when `docker` is on PATH. |
| `dkn` | `docker network` | Only when `docker` is on PATH. |
| `dknls` | `docker network ls` | Only when `docker` is on PATH. |
| `dknc` | `docker network create` | Only when `docker` is on PATH. |
| `dkni` | `docker network inspect` | Only when `docker` is on PATH. |
| `dknrm` | `docker network rm` | Only when `docker` is on PATH. |
| `dknp` | `docker network prune` | Only when `docker` is on PATH. |
| `dkncon` | `docker network connect` | Only when `docker` is on PATH. |
| `dkndis` | `docker network disconnect` | Only when `docker` is on PATH. |
| `dksys` | `docker system` | Only when `docker` is on PATH. |
| `dksdf` | `docker system df` | Only when `docker` is on PATH. |
| `ddfv` | `docker system df -v` | Only when `docker` is on PATH. |
| `dksev` | `docker system events` | Only when `docker` is on PATH. |
| `dksi` | `docker system info` | Only when `docker` is on PATH. |
| `dkcon` | `docker context` | Only when `docker` is on PATH. |
| `dcprune` | `docker container prune -f` | Only when `docker` is on PATH. |
| `diprune` | `docker image prune -f` | Only when `docker` is on PATH. |
| `dbprune` | `docker builder prune -f` | Only when `docker` is on PATH. |
| `dbx` | `docker buildx` | Only when `docker` is on PATH. |
| `dbxb` | `docker buildx build` | Only when `docker` is on PATH. |
| `dbxbp` | `docker buildx build --push` | Only when `docker` is on PATH. |
| `dbxls` | `docker buildx ls` | Only when `docker` is on PATH. |
| `dbxuse` | `docker buildx use` | Only when `docker` is on PATH. |
| `dbxcreate` | `docker buildx create` | Only when `docker` is on PATH. |
| `dbxinspect` | `docker buildx inspect` | Only when `docker` is on PATH. |
| `dbxrm` | `docker buildx rm` | Only when `docker` is on PATH. |
| `dbxstop` | `docker buildx stop` | Only when `docker` is on PATH. |
| `dbxmulti` | `docker buildx build --platform linux/amd64,linux/arm64` | Only when `docker` is on PATH. |
| `dstopall` | function | Stop all running containers. Only when `docker` is on PATH. |
| `drmall` | function | Remove all containers (including running) Only when `docker` is on PATH. |
| `drmiall` | function | Only when `docker` is on PATH. |
| `denter` | function | Quick shell into container. Only when `docker` is on PATH. |
| `dip` | function | Get container IP address. Only when `docker` is on PATH. |
| `dports` | function | Only when `docker` is on PATH. |
| `dco` | `docker compose` | Only when `docker` is on PATH. |
| `dcb` | `docker compose build` | Only when `docker` is on PATH. |
| `dce` | `docker compose exec` | Only when `docker` is on PATH. |
| `dcl` | `docker compose logs` | Only when `docker` is on PATH. Replaces `dcl='dot ai claude'` from `ai.aliases.sh`, which loads earlier. |
| `dclf` | `docker compose logs -f` | Only when `docker` is on PATH. |
| `dcps` | `docker compose ps` | Only when `docker` is on PATH. |
| `dcpull` | `docker compose pull` | Only when `docker` is on PATH. |
| `dcr` | `docker compose run` | Only when `docker` is on PATH. |
| `dcrestart` | `docker compose restart` | Only when `docker` is on PATH. |
| `dcrm` | `docker compose rm` | Only when `docker` is on PATH. |
| `dcstop` | `docker compose stop` | Only when `docker` is on PATH. |
| `dcup` | `docker compose up` | Only when `docker` is on PATH. |
| `dcupd` | `docker compose up -d` | Only when `docker` is on PATH. |
| `dcupb` | `docker compose up -d --build` | Only when `docker` is on PATH. |
| `dcdn` | `docker compose down` | Only when `docker` is on PATH. |
| `dcdownv` | `docker compose down -v` | Only when `docker` is on PATH. |
| `dksw` | `docker swarm` | Only when `docker` is on PATH, `docker swarm` succeeds. |
| `dkswi` | `docker swarm init` | Only when `docker` is on PATH, `docker swarm` succeeds. |
| `dkswj` | `docker swarm join` | Only when `docker` is on PATH, `docker swarm` succeeds. |
| `dkswl` | `docker swarm leave` | Only when `docker` is on PATH, `docker swarm` succeeds. |
| `dkswu` | `docker swarm update` | Only when `docker` is on PATH, `docker swarm` succeeds. |
| `dksrv` | `docker service` | Only when `docker` is on PATH, `docker swarm` succeeds. |
| `dksrvls` | `docker service ls` | Only when `docker` is on PATH, `docker swarm` succeeds. |
| `dksrvc` | `docker service create` | Only when `docker` is on PATH, `docker swarm` succeeds. |
| `dksrvi` | `docker service inspect` | Only when `docker` is on PATH, `docker swarm` succeeds. |
| `dksrvps` | `docker service ps` | Only when `docker` is on PATH, `docker swarm` succeeds. |
| `dksrvl` | `docker service logs` | Only when `docker` is on PATH, `docker swarm` succeeds. |
| `dksrvu` | `docker service update` | Only when `docker` is on PATH, `docker swarm` succeeds. |
| `dksrvu-force` | `docker service update --force` | Only when `docker` is on PATH, `docker swarm` succeeds. |
| `dksrvrm` | `docker service rm` | Only when `docker` is on PATH, `docker swarm` succeeds. |
| `dkstk` | `docker stack` | Only when `docker` is on PATH, `docker swarm` succeeds. |
| `dkstkls` | `docker stack ls` | Only when `docker` is on PATH, `docker swarm` succeeds. |
| `dkstkd` | `docker stack deploy` | Only when `docker` is on PATH, `docker swarm` succeeds. |
| `dkstkrm` | `docker stack rm` | Only when `docker` is on PATH, `docker swarm` succeeds. |
| `dkstkps` | `docker stack ps` | Only when `docker` is on PATH, `docker swarm` succeeds. |
| `dknode` | `docker node` | Only when `docker` is on PATH, `docker swarm` succeeds. |
| `dknodels` | `docker node ls` | Only when `docker` is on PATH, `docker swarm` succeeds. |
| `dknodei` | `docker node inspect` | Only when `docker` is on PATH, `docker swarm` succeeds. |
| `lzd` | `lazydocker` | Only when `lazydocker` is on PATH. |
| `ddive` | `dive` | Only when `dive` is on PATH. |
| `dlint` | `hadolint` | Only when `hadolint` is on PATH. |
| `dflint` | `hadolint Dockerfile` | Only when `hadolint` is on PATH. |

### Common Workflows

```bash
# Start a development container
dkri --name dev-container -v "$(pwd)":/app -p 3000:3000 node:latest bash

# Build and start the compose services in the background
dcupb

# Remove stopped containers, unused networks and dangling images
dcprune && dknp && diprune

# Deploy or update a stack from a compose file
dkstkd -c docker-compose.yml my-stack
```

[banner]: https://cloudcdn.pro/dotfiles/v2/images/titles/title-dotfiles.svg

---

Made with ❤️ by [Sebastien Rousseau](https://github.com/sebastienrousseau)
