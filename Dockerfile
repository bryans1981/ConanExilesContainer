FROM steamcmd/steamcmd:ubuntu-24

ENV DEBIAN_FRONTEND=noninteractive \
    APP_ID=443030 \
    WORKSHOP_APP_ID=440900 \
    STEAMCMD=steamcmd \
    SERVER_DIR=/serverdata/serverfiles \
    STEAM_DIR=/serverdata/steam \
    CONFIG_DIR=/serverdata/config \
    LOG_DIR=/serverdata/logs \
    BACKUP_LOCATION=/serverdata/backups

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        bash \
        ca-certificates \
        coreutils \
        findutils \
        gosu \
        grep \
        gzip \
        lib32gcc-s1 \
        lib32stdc++6 \
        netcat-openbsd \
        procps \
        sed \
        tar \
        tini \
        tzdata \
    && rm -rf /var/lib/apt/lists/*

RUN if ! getent group conan >/dev/null 2>&1; then groupadd -r conan; fi \
    && if ! id conan >/dev/null 2>&1; then useradd -r -m -g conan -s /bin/bash conan; fi \
    && mkdir -p /opt/steamcmd-template \
    && cp -a /root/.local/share/Steam /opt/steamcmd-template/Steam \
    && mkdir -p "${SERVER_DIR}" "${STEAM_DIR}" "${CONFIG_DIR}" "${LOG_DIR}" "${BACKUP_LOCATION}" \
    && chown -R conan:conan /serverdata

COPY scripts/ /scripts/
RUN chmod +x /scripts/*.sh

VOLUME ["/serverdata/serverfiles", "/serverdata/steam", "/serverdata/config", "/serverdata/logs", "/serverdata/backups"]

WORKDIR /serverdata

EXPOSE 7777/udp 7778/udp 27015/udp 25575/tcp 8080/tcp

HEALTHCHECK --start-period=15m --interval=60s --timeout=10s --retries=5 CMD ["/scripts/healthcheck.sh"]

ENTRYPOINT ["/usr/bin/tini", "--", "/scripts/entrypoint.sh"]
