# Fika SPT Docker Guide

Docker deployment for SPTushonka and Fika Server C#. The default combination is:

- SPTushonka `4.1.5`
- Fika Server C# `2.4.0`
- Fika Plugin `2.4.2` on every game client

The container supports `linux/amd64` and `linux/arm64` because it is derived
from the official multi-architecture SPTushonka image.

It intentionally keeps the official glibc-based SPT image. Alpine is not
supported by SPT 4.1.5 because its native dependencies are not published for
the `linux-musl` runtime identifiers.

## Requirements

- Docker Engine with Docker Compose v2
- A 64-bit amd64 or arm64 Linux host
- A local checkout of this guide

## Install

Copy the contents of `files/` to a new deployment directory. The directory is
the Docker build context and holds all persistent data and backups.

```sh
mkdir -p /srv/fika
cp -a files/. /srv/fika/
cd /srv/fika
cp .env.example .env
```

Alternatively, from this repository checkout run:

```sh
./files/setupScript/setup.sh /srv/fika
```

Edit `.env` before the first build:

- Set `PUID` and `PGID` to the owner of `/srv/fika/spt-user` (`id -u` and `id -g`).
- Keep `SPT_VERSION=4.1.5` and `FIKA_VERSION=2.4.0` for the supported default.
- Keep the matching `SPT_DIGEST` when changing `SPT_VERSION`. Obtain both values
  from the official SPTushonka container package page.

Build, back up existing data if present, and start the service:

```sh
./update.sh
```

Follow startup output with:

```sh
docker compose logs -f fika-server
```

The persistent server data is stored in `/srv/fika/spt-user`. Removing the
container does not remove this directory.

## First Fika Configuration

The first startup creates:

```text
spt-user/mods/fika-server/assets/configs/fika.jsonc
```

For a LAN or remote server, stop the container after this file appears, edit
the `server.SPT.http` values in `fika.jsonc`, then start it again:

```sh
docker compose stop
# edit spt-user/mods/fika-server/assets/configs/fika.jsonc
docker compose start
```

Set `backendIp` to the address clients can reach, never `0.0.0.0`. The service
always listens on container port `6969`; do not change `server.SPT.http.port`.
If you set `HOST_PORT` to a different host port, set only `backendPort` to that
same host port. Fika rewrites the SPT HTTP configuration from this file on every
startup, so changing only the upstream SPT backend setting after first boot is
not sufficient.

Install the matching client component from the
[Fika Plugin 2.4.2 release](https://github.com/project-fika/Fika-Plugin/releases/tag/v2.4.2)
on every player machine.

## Updates

Docker restarts do not update software. To update, edit the SPT version and its
matching manifest digest, plus the Fika version, in `.env`, then run
`./update.sh`:

```dotenv
SPT_VERSION=4.1.5
SPT_DIGEST=sha256:efd9ae3406b0b49769475828c393edffdc32f5df12e3bf130d7f446607a33ded
FIKA_VERSION=2.4.0
```

After a successful build, the script stops the server and creates
`backups/spt-user-<timestamp>.tar.gz` before recreating the container. During
the first boot of a new image, the bootstrap replaces Fika DLLs and static assets
while retaining Fika configuration and database files. SPT profiles, certificates,
logs, and all other server mods remain in `spt-user`.

Only select official stable SPT tags and published Fika Server C# releases. A
new SPT major version may require a matching Fika release. Keep a backup until
you have confirmed the new server works; profile migrations may prevent a safe
rollback after the updated server has started.

## Publish to GHCR

The `Build and publish SPT Fika image` workflow publishes a multi-architecture
image to `ghcr.io/<fork-owner>/spt-fika-server`. Run it manually from the
repository Actions tab after selecting an official SPT version, its matching
manifest digest, and a published Fika Server C# version.

The versioned tag is formatted as `4.1.5-fika-2.4.0`. Enable `tag_latest` only
when that combination is the default image you want users to pull. The workflow
uses the repository `GITHUB_TOKEN`; no personal access token is required.
After the first publication, set the package visibility to public in its GHCR
package settings if users must pull it without authenticating to GitHub.

## Useful Commands

```sh
# Stop without deleting data.
docker compose stop

# Start an existing container.
docker compose start

# View service state.
docker compose ps

# Stop and remove the container; spt-user remains intact.
docker compose down
```

For co-op connectivity and game-host port forwarding, follow the current
[Fika documentation](https://github.com/project-fika/Fika-Documentation).
