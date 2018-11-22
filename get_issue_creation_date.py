#!/usr/bin/env python

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

import os
import sys
import argparse

try:
    import requests
except:
    sys.stderr.write("Cannot import the 'requests' module, do you have it installed?\n")
    sys.exit(os.EX_UNAVAILABLE)


# from Chris
def gh_get_issue_created_at(url_issue):
    # type: (str) -> str
    prefix = "https://github.com/"
    if not prefix in url_issue:
        raise RuntimeError("Not a github issue url")
    owner, repo, _, number = url_issue[len(prefix):].split('/')
    url_api = 'https://api.github.com/repos/{}/{}/issues/{}'
    url_api = url_api.format(owner, repo, number)
    r = requests.get(url_api)
    created_at = r.json()['created_at']
    return created_at


parser = argparse.ArgumentParser()
parser.add_argument('URL', help='Issue url.')
args = parser.parse_args()

try:
    # github stamps are UTC
    sys.stdout.write(gh_get_issue_created_at(args.URL) + '\n')
except Exception as e:
    sys.stderr.write('Couldn\'t retrieve issue creation date: ' + str(e) + '\n')
    sys.exit(1)
