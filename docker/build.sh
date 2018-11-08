#!/bin/sh
VERSION="02"
docker build -t robust-rosin/rosinstall_generator_time_machine:${VERSION} --build-arg BUILD_VERSION=${VERSION} .
