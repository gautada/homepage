#!/bin/sh
#
# Health check: verifies the homepage application is responding on port 8080.
# Uses curl with a 5-second timeout to probe the HTTP endpoint.
# Returns 0 if homepage responds, non-zero otherwise.

if curl -sf --max-time 5 http://localhost:8080 > /dev/null 2>&1; then
  echo "Homepage is running on port 8080"
  exit 0
fi

echo "Homepage is not responding on port 8080"
exit 1
