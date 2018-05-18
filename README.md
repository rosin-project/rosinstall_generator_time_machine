# rosinstall_generator_time_machine

A simple bash script to generate `.rosinstall` files 'from the past'.


## Overview

This is a bash script that will, given a GitHub issue link, a date in the past and some other bits of information, try to generate a `.rosinstall` file using `rosinstall_generator` and a clone of `ros/rosdistro` as it was at the date specified.

The `.rosinstall` file can then be used to build the set of ROS packages that will approximate the 'state of ROS' as it was at the time the issue was reported.

## Usage

```
rosinstall_generator_time_machine.sh [ ISSUE_URL | ISO8601_DATETIME ] BUG_ID ROS_DISTRO PUT ROSINSTALL_FILENAME
```

Example invocation to generate a `.rosinstall` file, based on an issue opened on the `yujinrobot/kobuki_core` tracker on the 1st of March 2017 (note reuse of the cache):

```shell
user@machine:~$ rosinstall_generator_time_machine.sh \
  https://github.com/yujinrobot/kobuki_core/issues/29 \
  eed104d \
  kinetic \
  kobuki_ftdi \
  deps_eed104d.rosinstall
Switched to branch 'master'
Your branch is up-to-date with 'origin/master'.
Retrieving issue 'created_at' property for: https://github.com/yujinrobot/kobuki_core/issues/29
Found: 2017-03-01T08:57:20Z
Determined rosdistro commit: 2af311e205b874e862be155ffe21cb54e902f60b
Reusing existing branch
Switched to branch 'bughunt_eed104d'
Skipping rosdistro cache, already exists
Creating temporary rosdistro index ..
Using temporary index to generate rosinstall file (dependencies only) ..
Using ROS_DISTRO: kinetic
Storing metadata ..
Done
```

The same invocation, but with a datetime instead of an issue url:

```shell
rosinstall_generator_time_machine.sh \
  2017-03-01T08:57:20Z \
  eed104d \
  kinetic \
  kobuki_ftdi \
  deps_eed104d.rosinstall
...
```

**Note**: be prepared to have to press <kbd>RET</kbd> a few times for some repositories that no longer exist, or are now private repositories (for which `git` would need a password).

This will generate the `deps_eed104d.rosinstall` file containing all dependencies (and only the dependencies) of the `kobuki_ftdi` package in ROS Kinetic at the time that `yujinrobot/kobuki_core/issues/29` was reported. It will also generate a yaml file containing some metadata (`ros/rosdistro` commit used, issue created stamp, ROS distribution, etc) and a directory containing the `rosdistro` cache that was used to generate the `.rosinstall` file.

The temporary `rosdistro` index yaml in the working directory may be removed afterwards, it is not needed for anything.


## Requirements

In order to be able to run this, the following need to be present:

 - Python 2
 - git
 - `rosdistro` Python library ([this fork](https://github.com/gavanderhoorn/rosdistro_python/tree/rosin_bughunt_0.6.8), `rosin_bughunt_0.6.8` branch)
 - `rosinstall_generator`

It is recommended to install these dependencies (ie: `rosdistro` and `rosinstall_generator`) in a (Python 2) virtual environment.

For the helper script:

 - Python 3
 - PyGitHub (installed for Python 3)


## Limitations

The current implementation only supports `version 3` rosdistro yamls.
It also cannot reuse any caches that are 'close' or 'near' in time to a previous cache right now, leading to the tool always (re)building a rosdistro cache, even if there is only a minor time difference between two subsequent `rosdistro` commits.

It (obviously) cannot provide information on repositories that no longer exist (this becomes more of a problem the further back in time one goes).


## Future work

 - probably rewrite in Python
 - extend support to `version 2` and earlier versions of `rosdistro` (and related tools)
 - add reuse of existing caches that are 'near in time'
 - host caches in an online repository to avoid having to build them in the first place
 - silence `rosdistro_build_cache` a bit
 - expand metadata generation to include more details
 - distribute this tool in a Docker image
 - integrate with OSRF [Legacy ROS](https://hub.docker.com/r/osrf/ros_legacy/tags/) Docker images
