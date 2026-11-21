FROM yottadb/yottadb-base:latest

ARG TARGETARCH
ARG TTYD_VERSION=1.7.7

ENV DEBIAN_FRONTEND=noninteractive \
    TERM=xterm-256color \
    LANG=C.UTF-8 \
    DCRAWL_DB_DIR=/data/dcrawl

# Install static ttyd binary for the target architecture (amd64 / arm64)
RUN apt-get update -qq \
    && apt-get install -y --no-install-recommends ca-certificates curl \
    && case "${TARGETARCH}" in \
         amd64|"") TTYD_ARCH="x86_64" ;; \
         arm64)    TTYD_ARCH="aarch64" ;; \
         *)        echo "Unsupported arch: ${TARGETARCH}" >&2; exit 1 ;; \
       esac \
    && curl -fsSL "https://github.com/tsl0922/ttyd/releases/download/${TTYD_VERSION}/ttyd.${TTYD_ARCH}" -o /usr/local/bin/ttyd \
    && chmod +x /usr/local/bin/ttyd \
    && apt-get purge -y --auto-remove curl \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY src/ /app/src/
COPY txt/ /app/txt/
COPY scripts/run-session.sh scripts/docker-entrypoint.sh /app/scripts/

RUN chmod +x /app/scripts/run-session.sh /app/scripts/docker-entrypoint.sh \
    && mkdir -p /data/dcrawl \
    && bash -c 'source /usr/local/etc/ydb_env_set >/dev/null && for f in /app/src/*.m; do mumps -object=/app/src/ "$f" || exit 1; done'

EXPOSE 8080

ENTRYPOINT ["/app/scripts/docker-entrypoint.sh"]
