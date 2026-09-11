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

- Docker Engine
- A 64-bit amd64 or arm64 Linux host
- Docker Compose v2 and a local checkout only when building locally

## Deploy from GHCR

After publishing the image with the GitHub Actions workflow, a server can run it
directly without downloading this repository or building locally:

The GitHub account is `LucianoFaretra`; GHCR repository paths must be lowercase,
so the published image name is `ghcr.io/lucianofaretra/spt-fika-server`.

```sh
export IMAGE=ghcr.io/lucianofaretra/spt-fika-server:4.1.5-fika-2.4.0
mkdir -p /srv/spt
docker pull "$IMAGE"
docker run -d --name fika --restart unless-stopped \
  -e PUID="$(id -u)" \
  -e PGID="$(id -g)" \
  -p 6969:6969 \
  -p 6790:6790/udp \
  -v /srv/spt:/opt/server \
  "$IMAGE"
```

On first boot the container copies the complete SPT and Fika server tree into
`/srv/spt`. Keep this directory when replacing the container. If the GHCR
package is private, run `docker login ghcr.io` before pulling it.

## Networking

The container publishes `6969/TCP` for the SPT HTTP and WebSocket backend and
`6790/UDP` for Fika's optional self-hosted NAT-punch service. Do not publish
`6970`, `6971`, or `6972`: Fika Server C# does not listen on them.

The UDP port is always published, but Fika controls whether its NAT-punch
server listens on it. Enable or disable the NAT-punch service from Fika's
interface; no container rebuild or Compose setting is needed.

The raid itself is hosted by the game client, not this container. For direct
Fika raids, forward the game host's configured UDP port (`25565` by default)
on the machine running EscapeFromTarkov.exe.

To update a registry deployment, pull a new versioned image and recreate the
container with the same `/srv/spt` bind mount:

```sh
export IMAGE=ghcr.io/lucianofaretra/spt-fika-server:4.1.5-fika-2.4.0
docker pull "$IMAGE"
docker stop fika
docker rm fika
# Run the docker run command above again with the same bind mount.
```

## Build Locally

Copy the contents of `files/` to a deployment directory. It is the Docker build
context and holds the Compose files and backups; the complete persistent server
runtime is stored separately in `/srv/spt`.

```sh
mkdir -p /srv/fika /srv/spt
cp -a files/. /srv/fika/
cd /srv/fika
cp .env.example .env
```

Alternatively, from this repository checkout run:

```sh
./files/setupScript/setup.sh /srv/fika
```

Edit `.env` before the first build:

- Set `PUID` and `PGID` to the owner of `/srv/spt` (`id -u` and `id -g`).
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

The persistent server runtime is stored in `/srv/spt`. Removing the container
does not remove this directory.

### Migrate Existing Data

Deployments created with the earlier `spt-user` layout must move their existing
user data before the first full-runtime start:

```sh
docker compose down
mkdir -p /srv/spt/user
cp -a /srv/fika/spt-user/. /srv/spt/user/
```

## Server Mods

The full SPT installation is available in `/srv/spt`. Standard server mods go
in `/srv/spt/user/mods`; mods that provide files elsewhere must be extracted
with their release paths relative to `/srv/spt`. Stop the server before changing
files, then start it again:

```sh
docker compose stop
mkdir -p /srv/spt/user/mods
cp -a /path/to/mod /srv/spt/user/mods/
docker compose start
```

For a mod release containing paths such as `SPT_Data/...`, copy its contents
into `/srv/spt` instead. Client-side components still belong on each player's
game installation; follow the mod's own installation instructions for those.

## First Fika Configuration

The first startup creates:

```text
/srv/spt/user/mods/fika-server/assets/configs/fika.jsonc
```

For a LAN or remote server, stop the container after this file appears, edit
the `server.SPT.http` values in `fika.jsonc`, then start it again:

```sh
docker compose stop
# edit /srv/spt/user/mods/fika-server/assets/configs/fika.jsonc
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

## Local Build Updates

Docker restarts do not update software. To update, edit the SPT version and its
matching manifest digest, plus the Fika version, in `.env`, then run
`./update.sh`:

```dotenv
SPT_VERSION=4.1.5
SPT_DIGEST=sha256:efd9ae3406b0b49769475828c393edffdc32f5df12e3bf130d7f446607a33ded
FIKA_VERSION=2.4.0
```

After a successful build, the script stops the server and creates
`backups/spt-<timestamp>.tar.gz` before recreating the container. During the
first boot of a new image, the bootstrap copies the new SPT runtime over
`/srv/spt` and replaces Fika DLLs and static assets while retaining Fika
configuration and database files. Files changed in place by a mod can be
overwritten during an SPT update, so reinstall those mods after updating.

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

# Stop and remove the container; /srv/spt remains intact.
docker compose down
```

For co-op connectivity and game-host port forwarding, follow the current
[Fika documentation](https://github.com/project-fika/Fika-Documentation).

## Credits

This fork builds on the original work from
[Dildz/SPT-Fika-Docker-Guide](https://github.com/Dildz/SPT-Fika-Docker-Guide).
