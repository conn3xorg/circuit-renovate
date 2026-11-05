#!/usr/bin/env sh
# Runs where up.sh and forgejo.sh ran. Starts one Renovate run on the host
# from up.sh, waits for it, and checks it opened a pull request on
# renovate/demo that moves lodash off 4.17.20. Then checks the token is only
# in the root-only env file, not in Renovate's config.
set -eu
cd "$(dirname "$0")"
podman=${PODMAN:-podman}
name=${CONTAINER_NAME:-circuit-renovate}
. ./forgejo.env
fail() { echo "FAIL: $*" >&2; exit 1; }

# A oneshot service: start returns when the run ends, and fails if it did.
$podman exec "$name" systemctl start renovate.service || {
  $podman exec "$name" journalctl -u renovate.service --no-pager -n 40 >&2
  fail "the Renovate run failed"
}
pulls=$($podman exec "$name-forgejo" curl -sf -H "Authorization: token $FORGEJO_TOKEN" 'http://127.0.0.1:3000/api/v1/repos/renovate/demo/pulls?state=open')
echo "$pulls" | grep -q '"title":"[^"]*lodash' || fail "no pull request for lodash: $pulls"
echo "pull request: $(echo "$pulls" | grep -o '"title":"[^"]*lodash[^"]*"' | head -n 1)"

$podman exec "$name" grep -q "^RENOVATE_TOKEN=$FORGEJO_TOKEN\$" /etc/renovate/token.env || fail "the token isn't in token.env"
[ "$($podman exec "$name" stat -c '%U %a' /etc/renovate/token.env)" = "root 600" ] || fail "token.env isn't root-only"
if $podman exec "$name" grep -qF "$FORGEJO_TOKEN" /etc/renovate/config.json; then fail "the token is in config.json"; fi
echo "All checks passed."
