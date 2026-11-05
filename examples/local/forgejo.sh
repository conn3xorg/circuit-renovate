#!/usr/bin/env sh
# Starts a throwaway Forgejo for Renovate to work on, beside the host from
# up.sh, with a user "renovate", an access token and a repository
# renovate/demo whose package.json pins an old lodash. Writes the API address
# and the token to ./forgejo.env for the apply. Nothing here leaves the
# machine: the token is for this Forgejo only, and down.sh removes both.
# Forgejo publishes no port: the host container reaches it at its own address
# on Podman's default network, which is all Renovate needs.
set -eu
cd "$(dirname "$0")"
podman=${PODMAN:-podman}
name=${CONTAINER_NAME:-circuit-renovate}-forgejo
image=codeberg.org/forgejo/forgejo:17.0.1@sha256:fcd19ff4ebc85fb098a67e8e1d0d5a84d07dd6e8a23edcfdfd5b71a6178953be

$podman rm -f -v "$name" >/dev/null 2>&1 || true
$podman run -d --name "$name" \
  -e FORGEJO__security__INSTALL_LOCK=true \
  -e FORGEJO__database__DB_TYPE=sqlite3 \
  "$image" >/dev/null
ip=$($podman inspect "$name" --format '{{.NetworkSettings.IPAddress}}')

for _ in $(seq 120); do
  $podman exec "$name" curl -sf -o /dev/null http://127.0.0.1:3000/api/v1/version 2>/dev/null && break
  sleep 1
done
$podman exec -u git "$name" forgejo admin user create --admin --username renovate --email renovate@example.com --random-password --must-change-password=false >/dev/null
token=$($podman exec -u git "$name" forgejo admin user generate-access-token --username renovate --token-name ci --scopes all --raw)

api() { $podman exec -i "$name" curl -sf -H "Authorization: token $token" -H 'content-type: application/json' "$@"; }
echo '{"name":"demo","auto_init":true,"default_branch":"main"}' | api -X POST --data-binary @- http://127.0.0.1:3000/api/v1/user/repos >/dev/null
pkg=$(printf '{\n  "name": "demo",\n  "version": "1.0.0",\n  "dependencies": {\n    "lodash": "4.17.20"\n  }\n}\n' | base64 | tr -d '\n')
printf '{"content":"%s","message":"Add package.json"}' "$pkg" | api -X POST --data-binary @- http://127.0.0.1:3000/api/v1/repos/renovate/demo/contents/package.json >/dev/null

umask 077
printf 'FORGEJO_ENDPOINT=http://%s:3000/api/v1\nFORGEJO_TOKEN=%s\n' "$ip" "$token" > forgejo.env
echo "Forgejo is on http://$ip:3000, with renovate/demo. The endpoint and token are in forgejo.env."
