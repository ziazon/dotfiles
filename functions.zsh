# FileSearch
function f() { find . -iname "*$1*" ${@:2} }
function r() { grep "$1" ${@:2} -R . }

#mkdir and cd
function mkcd() { mkdir -p "$@" && cd "$_"; }

#kill process on port
function kill-port() { lsof -i tcp:$1 | awk 'NR!=1 {print $2}' | xargs kill }

function docker-clean() {
  docker_container_list=($(docker ps -a -q))

  if [[ ${docker_container_list} ]]; then
    echo "Stopping Containers:  ${docker_container_list}"
    docker stop ${docker_container_list}
  fi

  docker system prune --volumes --all -f

  echo "Docker Cleanup complete!"
}
