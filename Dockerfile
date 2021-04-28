FROM ghcr.io/wiserain/libtorrent:latest-ubuntu20.04-py3 AS libtorrent
FROM ghcr.io/linuxserver/baseimage-ubuntu:focal
LABEL maintainer="wiserain"
LABEL org.opencontainers.image.source https://github.com/wiserain/docker-sjva

ARG DEBIAN_FRONTEND="noninteractive"
ARG APT_MIRROR="archive.ubuntu.com"

# SYSTEM ENVs
ENV S6_BEHAVIOUR_IF_STAGE2_FAILS=2 \
    TZ=Asia/Seoul

# APP defaults
ENV PYTHONPATH=/app \
    VIRTUAL_ENV=/app/venv \
    SJVA_HOME=/app \
    SJVA_RUNNING_TYPE=docker \
    SJVA_PORT=9999 \
    REDIS_PORT=46379 \
    USE_CELERY=true \
    USE_GEVENT=true \
    CELERY_WORKER_COUNT=2

# update PATH
ENV PATH="$SJVA_HOME/data/command:$SJVA_HOME/data/bin:$VIRTUAL_ENV/bin:$PATH" \
    RCLONE_CONFIG="$SJVA_HOME/data/db/rclone.conf"

COPY requirements.txt ${SJVA_HOME}/

RUN \
    echo "**** prepare apt-get ****" && \
    sed -i "s/archive.ubuntu.com/$APT_MIRROR/g" /etc/apt/sources.list && \
    apt-get update -yqq && apt-get install -yqq --no-install-recommends apt-utils && \
    echo "**** install apt packages ****" && \
    apt-get install -y --no-install-recommends \
        `# python3` \
        python3 \
        python3-pip \
        python3-setuptools \
        python3-wheel \
        python3-venv \
        python3-babelfish \
        python3-gevent \
        python3-lxml \
        `# core` \
        git \
        lsof \
        curl \
        tzdata \
        bash-completion \
        unzip \
        wget \
        `# minimal` \
        redis \
        fuse \
        `# util` \
        sqlite3 \
        jq \
        vnstat \
        `# torrent_info` \
        'libboost-python[0-9.]+$' && \
    sed -i 's/#user_allow_other/user_allow_other/' /etc/fuse.conf && \
    echo "**** install python packages ****" && \
    python3 -m venv --system-site-packages $VIRTUAL_ENV && \
    apt-get install -y --no-install-recommends python3-dev gcc && \
    python3 -m pip install --no-cache-dir -r ${SJVA_HOME}/requirements.txt && \
    apt-get purge -y --auto-remove python3-dev gcc && \
    echo "**** install built-in apps ****" && \
    curl -fsSL https://raw.githubusercontent.com/filebrowser/get/master/get.sh | bash && \
    curl -fsSL https://raw.githubusercontent.com/wiserain/rclone/mod/install.sh | bash && \
    echo "**** cleanup ****" && \
    apt-get clean && \
    apt-get clean autoclean && \
    rm -rf \
        /tmp/* \
        /root/.cache \
        /var/lib/apt/lists/* \
        /var/tmp/*

# copy libtorrent libs
COPY --from=libtorrent /libtorrent-build/usr/lib/ /usr/lib/

# copy local files
COPY root/ /

HEALTHCHECK --interval=30s --timeout=30s --start-period=50s --retries=3 CMD curl 127.0.0.1:$(sqlite3 ${SJVA_HOME}/data/db/sjva.db "select value from system_setting where key='port'")/version || exit 1

VOLUME ${SJVA_HOME}/data
WORKDIR ${SJVA_HOME}/data
EXPOSE 9998 9999

ENTRYPOINT ["/init"]
