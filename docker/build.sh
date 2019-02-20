#!/bin/sh
VERSION="03"
SCRIPT_DIR=$(dirname $(readlink -f $0))
docker build -t robust-rosin/rosinstall_generator_time_machine:${VERSION} --build-arg BUILD_VERSION=${VERSION} ${SCRIPT_DIR}
