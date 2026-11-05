# Local example

Applies circuit-renovate to a throwaway Rocky Linux 10 container with systemd, pointed at a throwaway Forgejo beside it. You need Conn3x and Podman. Nothing here talks to a forge of yours, and no real token is involved.

Renovate runs under Podman inside the host container, so that container is privileged, which is simplest with rootful Podman. On a Mac, use the Podman machine's root connection. On Linux, use `sudo podman`:

```sh
export CONTAINER_CONNECTION=podman-machine-default-root   # macOS
export PODMAN="sudo podman"                               # Linux
./up.sh
./forgejo.sh
. ./forgejo.env
export TF_VAR_endpoint=$FORGEJO_ENDPOINT TF_VAR_token=$FORGEJO_TOKEN
conn3x init
conn3x apply
conn3x plan
```

[forgejo.sh](forgejo.sh) starts Forgejo 17 in its own container, makes a user `renovate` and an access token for it, and creates `renovate/demo` with a `package.json` that pins lodash 4.17.20. It writes Forgejo's API address and the token to `forgejo.env`.

The first apply installs Podman, pulls Renovate's image and checks the config with it. The second plan says `No changes.` Then run one pass, the way the timer would, and check it opened a pull request:

```sh
./check.sh
```

Renovate's log for the run is in the host's journal: `podman exec circuit-renovate journalctl -u renovate.service`.

`up.sh` listens on `127.0.0.1:2222`. Set `PORT` to use another port, and pass the same port to Conn3x with `-var port=PORT`. Set `CONTAINER_NAME` to name the containers something else, and `CONTAINERFILE` to test another distro, such as one of the images in Conn3x's `test/images`, which CI uses.

`./down.sh` removes both containers, their volumes, the key, `forgejo.env` and the state.
