# Pinned multi-arch manifest digest of yottadb/yottadb-base
FROM yottadb/yottadb-base@sha256:85364bd627bddc1885b87962d0b84944d48f1d8a9e37cdab2f5618496196208e

ARG TARGETARCH
ARG TTYD_VERSION=1.7.7
ARG TTYD_SHA256_AMD64=8a217c968aba172e0dbf3f34447218dc015bc4d5e59bf51db2f2cd12b7be4f55
ARG TTYD_SHA256_ARM64=b38acadd89d1d396a0f5649aa52c539edbad07f4bc7348b27b4f4b7219dd4165

ENV DEBIAN_FRONTEND=noninteractive \
    TERM=xterm-256color \
    LANG=C.UTF-8 \
    DCRAWL_DB_DIR=/data/dcrawl

# Install nginx-light + tini, verify static ttyd binary via SHA-256, then strip curl & SUID/SGID bits
RUN set -eu; \
    apt-get update -qq; \
    apt-get upgrade -y --no-install-recommends; \
    apt-get install -y --no-install-recommends ca-certificates curl nginx-light tini; \
    ARCH="${TARGETARCH:-$(dpkg --print-architecture)}"; \
    case "${ARCH}" in \
      amd64) TTYD_ARCH="x86_64";  TTYD_SHA256="${TTYD_SHA256_AMD64}" ;; \
      arm64) TTYD_ARCH="aarch64"; TTYD_SHA256="${TTYD_SHA256_ARM64}" ;; \
      *)     echo "Unsupported arch: ${ARCH}" >&2; exit 1 ;; \
    esac; \
    curl -fsSL "https://github.com/tsl0922/ttyd/releases/download/${TTYD_VERSION}/ttyd.${TTYD_ARCH}" -o /usr/local/bin/ttyd; \
    echo "${TTYD_SHA256}  /usr/local/bin/ttyd" | sha256sum -c -; \
    chmod 0755 /usr/local/bin/ttyd; \
    apt-get purge -y --auto-remove curl; \
    rm -rf /var/lib/apt/lists/*; \
    find / -xdev -perm /6000 -type f -exec chmod a-s {} +; \
    groupadd --gid 10001 --system dcrawl; \
    useradd --uid 10001 --gid 10001 --system --no-create-home --home-dir /nonexistent --shell /usr/sbin/nologin dcrawl

WORKDIR /app

COPY --chown=root:root src/ /app/src/
COPY --chown=root:root txt/ /app/txt/
COPY --chown=root:root config/ /app/config/
COPY --chown=root:root scripts/run-session.sh scripts/docker-entrypoint.sh /app/scripts/

RUN chmod 0755 /app /app/src /app/txt /app/config /app/scripts \
    && chmod 0644 /app/src/*.m /app/txt/*.txt /app/config/*.conf \
    && chmod 0755 /app/scripts/run-session.sh /app/scripts/docker-entrypoint.sh \
    && bash -c 'YDB_ENV_SET="/usr/local/etc/ydb_env_set"; [ -f "$YDB_ENV_SET" ] || YDB_ENV_SET="/opt/yottadb/current/ydb_env_set"; source "$YDB_ENV_SET" >/dev/null && for f in /app/src/*.m; do mumps -object=/app/src/ "$f" || exit 1; done' \
    && chmod 0644 /app/src/*.o \
    && install -d -o dcrawl -g dcrawl -m 0700 /data/dcrawl

EXPOSE 8080

HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD ["bash", "-c", "exec 3<>/dev/tcp/127.0.0.1/${PORT:-8080} && printf 'GET /healthz HTTP/1.0\\r\\nHost: localhost\\r\\n\\r\\n' >&3 && grep -q '200 OK' <&3"]

USER dcrawl

ENTRYPOINT ["/usr/bin/tini", "--", "/app/scripts/docker-entrypoint.sh"]
