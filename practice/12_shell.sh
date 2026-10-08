#!/usr/bin/env bash

# 12. Shell. Only what shell files do differently from the files before is
# here. `:e!` undoes.

# 1. The jq and awk programs below show with their own language's
#    highlighting, not as strings.
summary() {
  jq '.items[] | select(.qty > 1) | .name' "$1"
  awk -F, '{ total += $2 } END { print total }' "$1"
}

# 2. This file has a shebang, so on the first `:w` it becomes executable by
#    itself. Check with `:!ls -l %`. For files without a shebang, `<Space>oc`.

summary "$@"
