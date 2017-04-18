#!/bin/bash
# Override vars for oooq wrapper then poke deploy
# Do not use this as a separate.
set -uxe
cd /tmp/oooq
deploy.sh
