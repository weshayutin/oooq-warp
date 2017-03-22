#!/bin/bash
# Override vars for oooq wrapper then poke deploy
# Do not use this as a separate.
set -uxe
FUEL_DEVOPS=${FUEL_DEVOPS:-false}
[ "${FUEL_DEVOPS}" = "false" ] || . ./fuel-devops.sh
cd /tmp/oooq
deploy.sh
