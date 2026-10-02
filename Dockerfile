FROM node:26-bookworm-slim

ARG APP_VERSION=0.0.0
LABEL org.opencontainers.image.title="vaultwarden-sync"
LABEL org.opencontainers.image.description="Daily Vaultwarden → Vaultwarden sync"
LABEL org.opencontainers.image.version="${APP_VERSION}"
LABEL org.opencontainers.image.licenses="MIT"

ENV APP_VERSION=${APP_VERSION}
ENV BITWARDEN_CLI_VERSION=2026.7.0
ENV TZ=Asia/Hong_Kong
ENV SUPERCRONIC_VERSION=0.2.49

RUN apt-get update \
  && apt-get install -y --no-install-recommends bash curl jq ca-certificates tzdata \
  && rm -rf /var/lib/apt/lists/*

# Non-root scheduler (replaces system cron) / 非 root 排程器（取代系統 cron）
ARG TARGETARCH
RUN set -eux; \
  case "${TARGETARCH}" in \
    amd64) ARCH=amd64; SHA1SUM=e63c11a9726b775a6a11801e81af4f3fb926aa68 ;; \
    arm64) ARCH=arm64; SHA1SUM=0b6c5bb743e0b0dafed1132198c81807927ac413 ;; \
    *) echo "Unsupported arch: ${TARGETARCH}" >&2; exit 1 ;; \
  esac; \
  curl -fsSL -o /usr/local/bin/supercronic \
    "https://github.com/aptible/supercronic/releases/download/v${SUPERCRONIC_VERSION}/supercronic-linux-${ARCH}"; \
  echo "${SHA1SUM}  /usr/local/bin/supercronic" | sha1sum -c -; \
  chmod +x /usr/local/bin/supercronic

# Pin Bitwarden CLI version compatible with Vaultwarden / 釘住與 Vaultwarden 相容的 CLI 版本
RUN npm install -g "@bitwarden/cli@${BITWARDEN_CLI_VERSION}" \
  && bw --version

# Use the official node image non-root user (uid 1000) / 使用官方 node 映像既有的非 root 使用者
WORKDIR /app

COPY sync.sh /app/sync.sh
COPY entrypoint.sh /app/entrypoint.sh
COPY delete-ciphers.js /app/delete-ciphers.js
COPY i18n.sh /app/i18n.sh
COPY crontab /app/crontab
COPY VERSION /app/VERSION

RUN chmod +x /app/sync.sh /app/entrypoint.sh \
  && chown -R node:node /app

USER node

ENTRYPOINT ["/app/entrypoint.sh"]
