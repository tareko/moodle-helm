#!/usr/bin/env bash
#
# Ensure the shared `public-gateway` exposes the HTTPS listener that serves
# education.glia.org -> moodle-tls.
#
# Why this exists
# ---------------
# The Gateway lives on shared cluster infrastructure (namespace ingress-nginx)
# and is NOT created by this Helm chart (gateway.create=false). The chart's
# HTTPRoute attaches to it by listener name (`gateway.listenerName: https`).
# In Aug 2026 another service's server-side apply with --force-conflicts
# silently removed this listener, orphaning the HTTPRoute ("NoMatchingParent")
# and taking education.glia.org offline with a `tlsv1 unrecognized name` error.
#
# This script makes the listener reproducible and self-healing from CI.
# It is additive and idempotent: it only APPENDS the listener when it is
# missing and never rewrites the gateway's other listeners.
#
# Usage:
#   ./scripts/ensure-gateway-listener.sh
#
# Environment overrides:
#   GATEWAY_NAME       (default: public-gateway)
#   GATEWAY_NAMESPACE  (default: ingress-nginx)
#   LISTENER_NAME      (default: https)
#   LISTENER_HOSTNAME  (default: education.glia.org)

set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GATEWAY_NAME="${GATEWAY_NAME:-public-gateway}"
GATEWAY_NAMESPACE="${GATEWAY_NAMESPACE:-ingress-nginx}"
LISTENER_NAME="${LISTENER_NAME:-https}"
LISTENER_HOSTNAME="${LISTENER_HOSTNAME:-education.glia.org}"

if ! kubectl get gateway "$GATEWAY_NAME" -n "$GATEWAY_NAMESPACE" >/dev/null 2>&1; then
  echo "ERROR: gateway/$GATEWAY_NAME not found in namespace $GATEWAY_NAMESPACE." >&2
  echo "       It is managed outside this repo (shared cluster infra)." >&2
  exit 1
fi

# Exact whole-name match without a pipe. (`grep -q` in a pipeline exits early,
# which can SIGPIPE an upstream `tr`; under `set -o pipefail` that makes the
# pipeline return non-zero even on a match, so the check would misfire.)
listener_names="$(kubectl get gateway "$GATEWAY_NAME" -n "$GATEWAY_NAMESPACE" \
  -o jsonpath='{.spec.listeners[*].name}')"
case " $listener_names " in
  *" $LISTENER_NAME "*)
    current_host="$(kubectl get gateway "$GATEWAY_NAME" -n "$GATEWAY_NAMESPACE" \
      -o jsonpath='{.spec.listeners[?(@.name=="'"$LISTENER_NAME"'")].hostname}')"
    if [ "$current_host" = "$LISTENER_HOSTNAME" ]; then
      echo "Listener '$LISTENER_NAME' already present (hostname=$current_host); nothing to do."
      exit 0
    fi
    echo "WARNING: listener '$LISTENER_NAME' exists but hostname is '$current_host' (expected '$LISTENER_HOSTNAME')." >&2
    echo "         Refusing to modify it automatically; inspect the shared gateway." >&2
    exit 0
    ;;
esac

echo "Listener '$LISTENER_NAME' is missing; appending it to gateway/$GATEWAY_NAME ..."
kubectl patch gateway "$GATEWAY_NAME" -n "$GATEWAY_NAMESPACE" \
  --type=json --patch-file "$DIR/gateway/public-gateway-listener.json"

echo "Listener '$LISTENER_NAME' added for $LISTENER_HOSTNAME."
