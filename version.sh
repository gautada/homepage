#!/bin/sh
#
# Returns the version of the running homepage application.
# Reads directly from /app/package.json using jq.
# Returns non-zero if the version cannot be determined.

VERSION=$(jq -r '.version' /app/package.json | tr -d '[:space:]')

if [ -z "$VERSION" ] || [ "$VERSION" = "null" ]; then
  echo "Failed to read homepage version from /app/package.json" >&2
  exit 1
fi

printf '%s\n' "$VERSION"
