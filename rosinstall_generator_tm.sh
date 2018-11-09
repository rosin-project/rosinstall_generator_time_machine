#!/bin/bash
set -e

# Copyright (c) 2018, G.A. vd. Hoorn
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

EXIT_USAGE=64
if [ $# -lt 2 ];
then
  echo "USAGE: $0 TIMEPOINT ROS_DISTRO <ARGS>\

A wrapper around rosinstall_generator that makes it use rosdistro
caches 'from the past', allowing the generation of rosinstall
files with consistent sets of old releases of ROS packages.

Where:

  TIMEPOINT   An iso8601 datetime string (in the past)
  ROS_DISTRO  Name of the targeted ROS distribution/release
  ARGS        Arguments for rosinstall_generator. See the help
              of rosinstall_generator for more information

Note  : this script can be run without any arguments for
        rosinstall_generator. In that case it will just generate a
        cache for the specified TIMEPOINT and rosinstall_generator
        will print its usage information.

Note 2: pre REP-141 (before 24-Jan-2014) rosinstall_generator did
        not support the '--flat' argument."
  exit ${EXIT_USAGE}
fi

TIMEPOINT="$1"
ROS_DISTRO=$(echo "$2" | tr '[:upper:]' '[:lower:]')
ROSINSTALL_GENERATOR_ARGS=${@:3}

SCRIPT_DIR=$(dirname $(readlink -f $0))
RGTM_BASE_DIR="$HOME/.robust-rosin/rgtm"

RGTM_ROSDISTRO_CACHES_DIR="${RGTM_BASE_DIR}/rgtm_rosdistro_caches"
ROSDISTRO_CACHES_URL="https://github.com/gavanderhoorn/rgtm_rosdistro_caches.git"

ROSDISTRO_REPO_URL="https://github.com/ros/rosdistro.git"
ROSDISTRO_DIR="${RGTM_BASE_DIR}/rosdistro"
ROSDISTRO_SCRIPT_VENV_PRE141="pre141"
ROSDISTRO_SCRIPT_VENV_POST141="post141"
ROSDISTRO_SCRIPT_VENV=${ROSDISTRO_SCRIPT_VENV_POST141}
ROSDISTRO_PRE141_CUTOFF="2014-01-25T00:00:00Z"
ROSDISTRO_PRE137_CUTOFF="2013-04-22T13:14:47-0700"

DOCKER_IMAGE="robust-rosin/rosinstall_generator_time_machine:02"
DOCKER_RGTM_BASE_PATH="/rgtm"
DOCKER_RGTM_WORK_DIR="${DOCKER_RGTM_BASE_PATH}/work"
DOCKER_CONTAINER_CACHE_FILENAME="/cache.yaml.gz"
DOCKER_CONTAINER_ROSDISTRO_DIR="/rosdistro"
DOCKER_CONTAINER_INDEX_YAML_URI="${DOCKER_CONTAINER_ROSDISTRO_DIR}/index.yaml"


# check user requested a distribution we know about
if [[ ! "groovy hydro indigo jade kinetic lunar melodic" =~ "${ROS_DISTRO}" ]];
then
  printf "Requested an unsupported ROS distribution: '${2}', aborting\n" >&2
  exit ${EXIT_USAGE}
fi

# make sure all tools we need are available
for prog in date docker git sed; do
  if [ ! -x "$(command -v ${prog})" ]; then
    printf "Required program '${prog}' not found, aborting\n" >&2
    # TODO: proper exit code
    exit 1
  fi
done

# see whether current user can run docker directly
if ! docker > /dev/null 2>&1; then
  printf "Can't run 'docker' command as user '${USER}', aborting\n" >&2
  # TODO: proper exit code
  exit 1
fi

# see whether the Docker image exists locally
if ! docker image inspect ${DOCKER_IMAGE} > /dev/null 2>&1; then
  printf "Can't find Docker image '${DOCKER_IMAGE}' locally (and not pulling), aborting\n" >&2
  # TODO: proper exit code
  exit 1
fi

# see whether we need to create the (hidden) base dir for this tool
if [ ! -d "${RGTM_BASE_DIR}" ];
then
  printf "Creating rgtm base dir ..\n" >&2
  # TODO: check success and error out
  mkdir -p "${RGTM_BASE_DIR}" >&2
fi

# see whether we still need to clone rosdistro itself
# TODO: should we clone the 'special' fork of rosdistro from the robust org?
if [ ! -d "${ROSDISTRO_DIR}" ];
then
  printf "Need to clone rosdistro .. " >&2
  git clone -q ${ROSDISTRO_REPO_URL} "${ROSDISTRO_DIR}" >&2
  # TODO: error handling
  printf "done\n" >&2
fi

# see whether we need to download the initial set of caches
# TODO: yes, this only checks for existence of the directory
if [ ! -d "${RGTM_ROSDISTRO_CACHES_DIR}" ];
then
  printf "Need to retrieve some rosdistro caches .." >&2
  # TODO: error handling
  git clone -q ${ROSDISTRO_CACHES_URL} "${RGTM_ROSDISTRO_CACHES_DIR}" >&2
  printf "done\n" >&2
fi

# see what datetime user wants to take us back to
TIMEPOINT_EPOCH=$(date --date=${TIMEPOINT} +%s)
printf "Requested timepoint: '${TIMEPOINT}' (${TIMEPOINT_EPOCH})\n" >&2
if ! date -d ${TIMEPOINT} &> /dev/null;
then
  printf "Provided date '${TIMEPOINT}' is not a valid date so cannot continue ..\n" >&2
  exit ${EXIT_USAGE}
fi

# unfortunately we can't go back too far ..
if [ ${TIMEPOINT_EPOCH} -lt $(date --date="${ROSDISTRO_PRE137_CUTOFF}" +%s) ];
then
  printf "Date '${TIMEPOINT}' is too far in the past (REP-137 cutoff), sorry ..\n" >&2
  # TODO: find proper exit code
  exit 1
fi

# if we're going back to before 25 Jan 2014, we need to use older rosdistro support
if [ ${TIMEPOINT_EPOCH} -lt $(date --date="${ROSDISTRO_PRE141_CUTOFF}" +%s) ];
then
  printf "Switching to pre-REP-141 infrastructure ..\n" >&2
  ROSDISTRO_SCRIPT_VENV="${ROSDISTRO_SCRIPT_VENV_PRE141}"
fi


# always reset to master and revert any changes made
printf "Resetting local rosdistro clone ..\n" >&2
git -C "${ROSDISTRO_DIR}" checkout -q HEAD -- . >&2

# determine the commit 'closest' to the given timepoint
ROSDISTRO_COMMIT=$(git -C "${ROSDISTRO_DIR}" rev-list -n1 --before=${TIMEPOINT} master)
# TODO: do we want author or committer date here? Using author date for now.
ROSDISTRO_COMMIT_EPOCH=$(git -C "${ROSDISTRO_DIR}" log -n1 --date=format-local:'%s' --pretty=format:'%ad' ${ROSDISTRO_COMMIT})
printf "Determined rosdistro commit: ${ROSDISTRO_COMMIT:0:8} (authored: ${ROSDISTRO_COMMIT_EPOCH})\n" >&2

printf "Reverting to ros/rosdistro@${ROSDISTRO_COMMIT:0:8}\n" >&2
git -C "${ROSDISTRO_DIR}" checkout -q ${ROSDISTRO_COMMIT} >&2


# see whether we still need to generate a cache for this timepoint / commit
ROSDISTRO_CACHE_DIR="${RGTM_ROSDISTRO_CACHES_DIR}/${ROSDISTRO_COMMIT_EPOCH}"
ROSDISTRO_CACHE_FILENAME="${ROS_DISTRO}-cache.yaml.gz"
if [ -f "${ROSDISTRO_CACHE_DIR}/${ROSDISTRO_CACHE_FILENAME}" ]; then
  printf "Cache already exists for (distro; stamp) tuple, skipping generation\n" >&2

else
  # figure out closest cache dir
  # TODO: error handling
  CLOSEST_CACHE_DIR=$(${SCRIPT_DIR}/find_closest_cache.py -a ${RGTM_ROSDISTRO_CACHES_DIR} ${ROS_DISTRO} ${ROSDISTRO_COMMIT_EPOCH})
  printf "Base cache for new cache: ${CLOSEST_CACHE_DIR}\n" >&2

  # needs to be generated
  printf "Will store new cache in: ${ROSDISTRO_CACHE_DIR}\n" >&2
  mkdir -p "${ROSDISTRO_CACHE_DIR}" >&2

  # make current index.yaml point to historical cache we use as a basis for the new one
  sed -ri "s|(distribution_cache\|release_cache):.*|\1: file://${DOCKER_CONTAINER_CACHE_FILENAME}|g" ${ROSDISTRO_DIR}/index.yaml >&2

  printf "Building cache ..\n" >&2
  # TODO: error handling
  docker run \
    -it \
    --rm \
    --user=$(id -u):$(id -g) \
    -v "${CLOSEST_CACHE_DIR}/${ROSDISTRO_CACHE_FILENAME}":${DOCKER_CONTAINER_CACHE_FILENAME}:ro \
    -v "${ROSDISTRO_DIR}":${DOCKER_CONTAINER_ROSDISTRO_DIR}:ro \
    -v "${ROSDISTRO_CACHE_DIR}":${DOCKER_RGTM_WORK_DIR} \
    ${DOCKER_IMAGE} \
      "${DOCKER_RGTM_BASE_PATH}/${ROSDISTRO_SCRIPT_VENV}/bin/rosdistro_build_cache" \
        --ignore-errors \
        ${DOCKER_CONTAINER_INDEX_YAML_URI} \
        ${ROS_DISTRO}

  # we don't ever use the non-compressed file
  rm "${ROSDISTRO_CACHE_DIR}/${ROS_DISTRO}-cache.yaml"

  # store some metadata
  echo "Cache(s) for ros/rosdistro@${ROSDISTRO_COMMIT:0:8}." > "${ROSDISTRO_CACHE_DIR}/readme.txt"
fi

printf "Updating local rosdistro index.yaml to use cache from the past ..\n" >&2
sed -ri "s|(distribution_cache\|release_cache):.*|\1: file://${DOCKER_CONTAINER_CACHE_FILENAME}|g" ${ROSDISTRO_DIR}/index.yaml >&2

printf "Invoking: rosinstall_generator --rosdistro=${ROS_DISTRO} ${ROSINSTALL_GENERATOR_ARGS}\n" >&2
# we don't use '-t' here to avoid stderr to be mixed with stdout
docker run \
  -i \
  --rm \
  --user=$(id -u):$(id -g) \
  -e ROSDISTRO_INDEX_URL="file://${DOCKER_CONTAINER_INDEX_YAML_URI}" \
  -v "${ROSDISTRO_CACHE_DIR}/${ROSDISTRO_CACHE_FILENAME}":${DOCKER_CONTAINER_CACHE_FILENAME}:ro \
  -v "${ROSDISTRO_DIR}/index.yaml":${DOCKER_CONTAINER_INDEX_YAML_URI}:ro \
  ${DOCKER_IMAGE} \
    "${DOCKER_RGTM_BASE_PATH}/${ROSDISTRO_SCRIPT_VENV}/bin/rosinstall_generator" \
      --rosdistro=${ROS_DISTRO} \
      ${ROSINSTALL_GENERATOR_ARGS}
