#!/bin/sh
VERSION="03"
docker build -t robust-rosin/rosinstall_generator_time_machine:${VERSION} --build-arg BUILD_VERSION=${VERSION} .
