#!/usr/bin/env bash
# Runs inside the throwaway repository, with the fixture state already in place.
#
# Leaves Branch and HEAD deliberately mismatched: the drift notice is what this case
# tests. Also creates the stash the state names, so Resume step 2 has something to find.
set -euo pipefail

git switch -q -c refactor/split-notification-service
printf 'wip\n' > wip.txt
git -c core.autocrlf=false add wip.txt   # the warning is noise in a throwaway repo
git stash push -q -m "wip split notification service"
git switch -q -c fix/notifications-index
