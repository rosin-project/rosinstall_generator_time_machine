# rosinstall_generator_time_machine

A simple bash script to generate `.rosinstall` files 'from the past'.


## Overview

This bash script is a wrapper around `rosinstall_generator` that accepts one additional argument: a date in the past.

Using this datetime stamp, it will try to generate a `.rosinstall` file using `rosinstall_generator` and a clone of `ros/rosdistro` as that repository was at the date specified.

The `.rosinstall` file can then be used to build the set of ROS packages that will approximate the 'state of ROS' as it was at the time the issue was reported ('approximate', as we only revert rosdistro, not the rosdep database, nor the base OS).

## Usage

```
rosinstall_generator_tm.sh ISO8601_DATETIME ROS_DISTRO [ other rosinstall_generator args ]
```

Example invocation to generate a `.rosinstall` file based on an issue opened on the `yujinrobot/kobuki_core` tracker on the 1st of March 2017 (note reuse of the cache):

```shell
user@machine:~$ get_issue_creation_date.py https://github.com/yujinrobot/kobuki_core/issues/29
2017-03-01T08:57:20Z
user@machine:~$ rosinstall_generator_tm.sh \
  '2017-03-01T08:57:20Z' \
  kinetic \
  kobuki_ftdi \
  --deps --deps-only --tar > deps.rosinstall
Requested timepoint: '2014-07-28T09:14:56Z' (1406538896)
Resetting local rosdistro clone ..
Previous HEAD position was 2b0f84c... jsk_common: 1.0.33-0 in 'hydro/distribution.yaml' [bloom]
Switched to branch 'master'
Your branch is up-to-date with 'origin/master'.
Determined rosdistro commit: 2b0f84cf (authored: 1406540365)
Reverting to ros/rosdistro@2b0f84cf
Cache already exists for (distro; stamp) tuple, skipping generation
Updating local rosdistro index.yaml to use cache from the past ..
Invoking: rosinstall_generator --rosdistro=kinetic kobuki_ftdi --deps --deps-only --tar
Using ROS_DISTRO: kinetic
user@machine:~$
```

**Note**: be prepared to press <kbd>RET</kbd> or <kbd>ENTER</kbd> a few times for some repositories that no longer exist, or are now private repositories (and for which `git` would now need a password).

This will generate the `deps.rosinstall` file containing all dependencies (and *only* the dependencies) of the `kobuki_ftdi` package in ROS Kinetic at the time that `yujinrobot/kobuki_core/issues/29` was reported.

If a rosdistro cache was not already available for the timepoint and ROS version requested, one will be generated using the closest available cache as a starting point.


## Requirements

In order to be able to run this, the following need to be present:

 - Docker
 - git
 - sed
 - date
 - Python 2

Most of the runtime infrastructure will be installed into a Docker image.

The script will also check for the presence of these tools and programs.


## Setup and installation

Installation consists of cloning the Github repository to a suitable location.

Now run the `build.sh` script in the `docker` sub directory. This should build a Docker image containing the runtime infrastructure.

At this point setup is complete and the tool can be used.

For convenience the directory containing `rosinstall_generator_tm.sh` may be placed on the `PATH`.


## Limitations

The current implementation can only go back to 22nd of April, 2013 (on that date updates to various packages including `rosdistro` and `rosinstall_generator` was rolled out for REP-137 compliance).

It (obviously) cannot provide information on repositories that no longer exist (this becomes more of a problem the further back in time one goes).


## Future work

 - probably rewrite in Python
 - extend support to `version 2` and earlier versions of `rosdistro` (and related tools)
 - silence `rosdistro_build_cache` a bit
 - distribute this tool in a Docker image
 - integrate with OSRF [Legacy ROS](https://hub.docker.com/r/osrf/ros_legacy/tags/) Docker images

## FAQ

Some frequently asked questions and answers.

#### Date YYYY-MM-DDTHH:MM:SS too far in the past

This error is printed whenever the script is asked to go back to a date that is beyond what is currently supported (22nd of April, 2013).

#### No packages/stacks left after ignoring not released

After figuring out the `rosdistro` commit, the script uses `rosinstall_generator` to generate a `.rosinstall` file with all the dependencies of the specified PUT. For this to work, the PUT itself must have been released (and thus registered in `rosdistro`) at the date and time that the time machine was asked to go back to.

Make sure this is the case if running into this error. Realise that the package may not have been released at the time the bug was reported (if using the issue URL as input to the time machine).
