# Setup Helper

Run this script from a checkout of this repository to copy the current Docker
configuration into a deployment directory:

```sh
./setup.sh /srv/fika
```

It creates `Dockerfile`, `compose.yaml`, `.env.example`, `update.sh`, and the
Fika bootstrap entrypoint. Existing files are never overwritten. Edit
`/srv/fika/.env`, then run `/srv/fika/update.sh` to create the image and start
the server.
