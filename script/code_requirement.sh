#!/bin/bash
set -euo pipefail
# Pin every architecture of an ad-hoc signed binary. Apple certificate chains
# are deliberately unnecessary; identifiers alone are never authentication.
[[ $# -eq 1 ]] || { echo 'Usage: code_requirement.sh MACH_O_BINARY' >&2; exit 2; }
requirement=''
for architecture in $(/usr/bin/lipo -archs "$1"); do
    hash=$(/usr/bin/codesign -d --arch "$architecture" --verbose=4 "$1" 2>&1 | /usr/bin/sed -n 's/^CDHash=//p')
    [[ "$hash" =~ ^[0-9a-f]{40}$ ]] || { echo 'Missing CodeDirectory hash' >&2; exit 1; }
    [[ -z "$requirement" ]] || requirement+=' or '
    requirement+="cdhash H\"$hash\""
done
[[ -n "$requirement" ]] || exit 1
printf '%s\n' "$requirement"
