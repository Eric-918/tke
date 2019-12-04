#! /usr/bin/env bash

# Tencent is pleased to support the open source community by making TKEStack
# available.
#
# Copyright (C) 2012-2019 Tencent. All Rights Reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License"); you may not use
# this file except in compliance with the License. You may obtain a copy of the
# License at
#
# https://opensource.org/licenses/Apache-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
# WARRANTIES OF ANY KIND, either express or implied.  See the License for the
# specific language governing permissions and limitations under the License.

set -o errexit
set -o nounset
set -o pipefail

umask 0022
unset IFS
unset OFS
unset LD_PRELOAD
unset LD_LIBRARY_PATH

export PATH='/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin'

VERSION=latest

INSTALL_DIR=/opt/tke-installer
DATA_DIR=$INSTALL_DIR/data
OPTIONS="--name tke-installer -d --privileged --net=host -v/etc/hosts:/app/hosts -v/var/run/docker.sock:/var/run/docker.sock -v$DATA_DIR:/app/data -v$INSTALL_DIR/conf:/app/conf"

function prefight() {
  echo "Step.1 prefight"

  if [ "root" != "$(whoami)" ]; then
    echo "only root can execute this script"
    exit 1
  fi
}

function ensure_docker() {
  echo "Step.2 ensure docker is ok"

  if ! [ -x "$(command -v docker)" ]; then
    echo "command docker not find"
    install_docker
  fi
  if ! systemctl is-active --quiet docker; then
    echo "docker status is not running"
    install_docker
  fi
}

function install_docker() {
  echo "install docker [doing]"

  tar xvaf "res/docker.tgz" -C /usr/bin --strip-components=1
  cp -v res/docker.service /etc/systemd/system

  systemctl daemon-reload

  if ! systemctl start docker; then
    echo "can't start docker, please check docker service."
    exit 1
  fi
  if ! systemctl is-active --quiet docker; then
    echo "docker status is not running, please check docker service."
    exit 1
  fi

  echo "install docker [ok]"
}

function load_image() {
  echo "Step.3 load tke-installer image"

  docker load -i res/tke-installer.tgz
}

function clean_old_data() {
  echo "Step.4 clean old data"

  rm -rf $DATA_DIR
  docker rm -f tke-installer
}

function start_installer() {
  echo "Step.5 start tke-installer"

  docker run $OPTIONS tkestack/tke-installer:$VERSION
}

function check_installer() {
  echo "Step.6 check tke-installer status is ok"

  ip=$(ip route get 1 | awk '{print $NF;exit}')
  if curl -sSf "http://$ip:8080/index.html" >/dev/null; then
    echo "check installer status error"
    docker logs tke-installer
    exit 1
  fi
}

prefight
ensure_docker
load_image
clean_old_data
start_installer
check_installer
