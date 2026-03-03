#!/bin/sh
# Test script to verify HTTP status of Moodle deployment
# Usage: ./http_status_test.sh [URL] [EXPECTED_STATUS]
# Returns exit code 0 if status matches expected, 1 otherwise

set -eu

URL="${1:-http://education.glia.org}"
EXPECTED="${2:-200}"

echo "Testing: $URL"
echo "Expected status: $EXPECTED"

STATUS=$(curl -s -L -o /dev/null -w "%{http_code}" --max-time 30 "$URL")

echo "Actual status: $STATUS"

if [ "$STATUS" = "$EXPECTED" ]; then
  echo "PASS: Got expected HTTP $EXPECTED"
  exit 0
else
  echo "FAIL: Expected HTTP $EXPECTED but got $STATUS"

  # Show more details for debugging
  echo ""
  echo "--- Response details ---"
  curl -sS -D - -o /tmp/response_body.html --max-time 30 "$URL" 2>&1 | head -20
  echo ""
  echo "--- Response body (first 50 lines) ---"
  head -50 /tmp/response_body.html 2>/dev/null || true

  exit 1
fi
