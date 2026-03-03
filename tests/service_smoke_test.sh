#!/bin/sh
set -eu

URL="${1:-http://education.glia.org}"
TMP_HEADERS="/tmp/moodle_headers.txt"
TMP_BODY="/tmp/moodle_body.html"

curl -sS -L -D "$TMP_HEADERS" -o "$TMP_BODY" "$URL"

STATUS="$(awk 'toupper($1) ~ /^HTTP\// {code=$2} END {print code}' "$TMP_HEADERS")"
if [ "$STATUS" != "200" ]; then
  echo "FAIL: expected HTTP 200 from $URL, got $STATUS"
  echo "--- response headers ---"
  sed -n '1,40p' "$TMP_HEADERS"
  echo "--- response body ---"
  sed -n '1,80p' "$TMP_BODY"
  exit 1
fi

if ! grep -Eiq '<html|<head|<body' "$TMP_BODY"; then
  echo "FAIL: response from $URL does not look like a normal HTML page"
  sed -n '1,80p' "$TMP_BODY"
  exit 1
fi

echo "PASS: $URL returned HTTP 200 and HTML content"
