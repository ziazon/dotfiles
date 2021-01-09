# FileSearch
function f() { find . -iname "*$1*" ${@:2} }
function r() { grep "$1" ${@:2} -R . }

#mkdir and cd
function mkcd() { mkdir -p "$@" && cd "$_"; }

#kill process on port
function kill-port() {
  pid=($(lsof -i tcp:$1 | awk 'NR!=1 {print $2}'))
  [ -z "${pid}" ] || kill ${pid}
}

function docker-clean() {
  docker_container_list=($(docker ps -a -q))

  if [[ ${docker_container_list} ]]; then
    echo "Stopping Containers:  ${docker_container_list}"
    docker stop ${docker_container_list}
  fi

  docker system prune --volumes --all -f

  echo "Docker Cleanup complete!"
}

function backup-env-files() {
  mkdir -p backups
  find . -type f \( -name '.envrc' -o -name '.env' \) | sed -e 'p; s/\/\./-/g; s/\//-/g; s/\.-/backups\//g; s/\(.*\)-/\1\./' | xargs -n2 cp
}

pg() {
  docker run -p 5432:5432 -e POSTGRES_PASSWORD=password -m 2g -d postgres
}
