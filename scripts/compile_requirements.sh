#!/bin/bash
set -euo pipefail

if [ $# -eq 0 ]; then echo "Usage: $0 <context>"; exit 1; fi

name="compile_requirements"

if [ $(docker images -q $name | wc -l) -ne 1 ]; then
    docker run -i \
        --name $name \
        -e "DEBIAN_FRONTEND=noninteractive" \
        ubuntu:20.04 \
        bash -c "apt-get update -qq && apt-get install -yqq python3-pip python3-wheel && python3 -m pip install pip-tools"
    docker commit $name $name
fi

cid=$(docker ps -a | grep $name | awk '{print $1}')
docker run --rm -i -v ${PWD}/$1:/req $name \
    bash -c "cd /req && pip-compile -U"
sudo chown $(id -u):$(id -g) $1/requirements.*
