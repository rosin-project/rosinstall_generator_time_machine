#!/usr/bin/env python
# -*- coding: utf-8 -*-

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


# searches for the sub dir in BASE_DIR that:
#
#  a) has a rosdistro cache file for DISTRO, and
#  b) is closest in terms of time based on 'dir name -> epoch' conversion
#
# If there is a direct match (so a cache for DISTRO in a dir for the
# exact STAMP) that is returned.
#
# In absence of a direct match, all dirs with a cache for DISTRO are
# checked for distance to STAMP. The closest one will be returned.
#
# If there are no dirs with caches for DISTRO, then an empty
# string is returned and the exit status is 1.
#
# Exit status is 0 in all other cases.


# this script expects a directory structure with compressed rosdistro
# cache files sorted according to timestamp.
#
# Example:
#
#   BASE_DIR
#   └── 123456789
#       └── hydro-cache.yaml.gz
#
# each directory (with a 'unix epoch stamp' as name) can contain
# cache files for each of the ROS repositories.


import datetime
import dateutil.parser
from os import path, listdir
import sys
import argparse

from bisect import bisect_left


verbose = False
def log(s):
    if verbose:
        sys.stderr.write(s + '\n')


def find_closest_entry(lst, n):
    idx = bisect_left(lst, n)
    if idx == 0:
        return lst[0]
    if idx == len(lst):
        return lst[-1]
    before = lst[idx - 1]
    after = lst[idx]
    if (after - n) < (n - before):
        return after
    else:
        return before

def has_cache_file(d, distro):
    return path.isfile(path.join(d, distro + '-cache.yaml.gz'))


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('-a', '--absolute', action='store_true',
        dest='absolute', help='Return absolute paths (default: return relative paths)')
    parser.add_argument('-v', '--verbose', action='store_true', dest='verbose')
    parser.add_argument('BASE_DIR', help='The base cache directory')
    parser.add_argument('DISTRO', help='The ROS distro to find the closest cache dir for')
    parser.add_argument('STAMP', help='The Unix epoch or ISO 8601 datetime '
        'to find the closest cache dir for')
    args = parser.parse_args()

    verbose = args.verbose
    base_dir = args.BASE_DIR
    stamp = args.STAMP
    ros_distro = args.DISTRO.lower()

    if 't' in stamp.lower() or ':' in stamp:
        # assume it's an ISO 8601 datetime, so convert
        stamp = dateutil.parser.parse(stamp).strftime('%s')

    iso_date = datetime.datetime.utcfromtimestamp(float(stamp)).isoformat() + 'Z'
    log("INFO: searching for {} cache closest to: {} ({})".format(ros_distro, stamp, iso_date))
    log("INFO: using rosdistro cache dir: {}".format(base_dir))

    # if we have an exact match (ie: cache exists for stamp), just return that
    candidate = path.join(base_dir, stamp)
    if has_cache_file(candidate, ros_distro):
        log("INFO: found exact match, returning: {}".format(candidate))
        closest_cache_path = candidate

    else:
        # no exact match: filter all candidates based on whether they have
        # a cache file for the distribution we're interested in
        # find_cache_dirs_for_distro(base_dir, ros_distro)
        candidates = [d for d in listdir(base_dir) if has_cache_file(path.join(base_dir, d), ros_distro)]
        epochs = [int(d) for d in candidates if d.isdigit()]
        if not epochs:
            log("ERR : no candidates left after filtering")
            closest_cache_path = ''

        else:
            entry = find_closest_entry(epochs, int(stamp))
            closest_cache_path = path.join(base_dir, str(entry))

        log("INFO: closest cache dir: {}".format(closest_cache_path))

    if args.absolute and closest_cache_path != '':
        closest_cache_path = path.abspath(closest_cache_path)

    log("INFO: returning: {}".format(closest_cache_path))
    print (closest_cache_path)
    sys.exit(0 if closest_cache_path != '' else 1)
