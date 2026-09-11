# Set these from an official stable image at
# https://github.com/orgs/SP-Tushonka/packages/container/server-csharp.
ARG SPT_VERSION=4.1.5
ARG SPT_DIGEST=sha256:efd9ae3406b0b49769475828c393edffdc32f5df12e3bf130d7f446607a33ded
FROM ghcr.io/sp-tushonka/server-csharp:${SPT_VERSION}@${SPT_DIGEST}

ARG SPT_VERSION
ARG SPT_DIGEST
ARG FIKA_VERSION=2.4.0

USER root

# The SPT image already provides curl and jq. Resolve the Fika release asset from
# GitHub and verify GitHub's published SHA-256 digest before baking it into the image.
RUN set -eux; \
    apt-get update; \
    apt-get install -y --no-install-recommends unzip; \
    rm -rf /var/lib/apt/lists/*; \
    release_json="$(curl -fsSL "https://api.github.com/repos/project-fika/Fika-Server-CSharp/releases/tags/v${FIKA_VERSION}")"; \
    asset_url="$(printf '%s' "$release_json" | jq -er '[.assets[] | select(.content_type == "application/zip")] | if length == 1 then .[0].browser_download_url else error("expected exactly one Fika ZIP asset") end')"; \
    asset_digest="$(printf '%s' "$release_json" | jq -er '[.assets[] | select(.content_type == "application/zip")] | if length == 1 then .[0].digest else error("expected exactly one Fika ZIP asset") end | sub("^sha256:"; "")')"; \
    test "${#asset_digest}" = 64; \
    mkdir -p /tmp/fika /opt/fika-dist; \
    curl -fsSL "$asset_url" -o /tmp/fika.zip; \
    echo "$asset_digest  /tmp/fika.zip" | sha256sum -c -; \
    unzip -q /tmp/fika.zip -d /tmp/fika; \
    test -d /tmp/fika/SPT_Runtime/user/mods/fika-server; \
    cp -a /tmp/fika/SPT_Runtime/user/mods/fika-server/. /opt/fika-dist/; \
    printf '%s\n' "$FIKA_VERSION" > /opt/fika-dist/.version; \
    rm -rf /tmp/fika /tmp/fika.zip

COPY fika-entrypoint.sh /usr/local/bin/fika-entrypoint.sh
RUN chmod +x /usr/local/bin/fika-entrypoint.sh

LABEL org.opencontainers.image.title="Fika SPT Server" \
      org.opencontainers.image.description="SPTushonka with the Fika server mod" \
      org.opencontainers.image.version="${SPT_VERSION}-fika-${FIKA_VERSION}" \
      org.opencontainers.image.source="https://github.com/SP-Tushonka/server-csharp"

# Preserve the upstream entrypoint: it configures SPT networking and drops to PUID:PGID.
EXPOSE 6790/udp
ENTRYPOINT ["/usr/local/bin/fika-entrypoint.sh"]
