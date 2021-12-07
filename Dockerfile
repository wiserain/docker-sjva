FROM ghcr.io/wiserain/libtorrent:latest-ubuntu20.04 AS libtorrent
FROM ghcr.io/linuxserver/baseimage-ubuntu:focal
LABEL maintainer="wiserain"
LABEL org.opencontainers.image.source https://github.com/wiserain/docker-sjva

ARG DEBIAN_FRONTEND="noninteractive"
ARG APT_MIRROR="archive.ubuntu.com"

# SYSTEM ENVs
ENV S6_BEHAVIOUR_IF_STAGE2_FAILS=2 \
    PYTHONUNBUFFERED=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1 \
    PIP_NO_CACHE_DIR=1 \
    PUID=0 \
    PGID=0 \
    TZ=Asia/Seoul

# APP defaults
ENV HOME=/app \
    SJVA_RUNNING_TYPE=docker \
    SJVA_REPEAT_COUNT=0 \
    CELERY_APP=sjva3.celery \
    SJVA_PORT=9999 \
    REDIS_PORT=46379 \
    USE_CELERY=true \
    USE_GEVENT=true \
    CELERY_WORKER_COUNT=2 \
    PLUGIN_UPDATE_FROM_PYTHON=false

# update PATH
ENV PATH="$HOME/data/command:$HOME/data/bin:$HOME/.local/bin:$PATH" \
    PYTHONPATH="${PYTHONPATH:+$PYTHONPATH:}$HOME"

COPY requirements.txt ${HOME}/

RUN \
    echo "**** prepare apt-get ****" && \
    sed -i "s/archive.ubuntu.com/$APT_MIRROR/g" /etc/apt/sources.list && \
    apt-get update -yqq && apt-get install -yqq --no-install-recommends apt-utils && \
    echo "**** install apt packages ****" && \
    apt-get install -y --no-install-recommends \
        `# python3` \
        python3 \
        python3-pip \
        python3-wheel \
        python3-gevent \
        python3-lxml \
        python3-pil \
        `# core` \
        curl \
        git \
        sqlite3 \
        tzdata \
        unzip \
        wget \
        `# minimal` \
        ffmpeg \
        fuse \
        redis \
        `# util` \
        bash-completion \
        jq \
        vnstat \
        `# torrent_info` \
        'libboost-python[0-9.]+$' && \
    if [ ! -e /usr/bin/python ]; then ln -sf /usr/bin/python3 /usr/bin/python; fi && \
    if [ ! -e /usr/bin/pip ]; then ln -s pip3 /usr/bin/pip; fi && \
    sed -i 's/#user_allow_other/user_allow_other/' /etc/fuse.conf && \
    echo "**** setting locale to en_US.UTF-8 ****" && \
    locale-gen en_US.UTF-8 && \
    update-locale LC_ALL=en_US.UTF-8 LANG=en_US.UTF-8 && \
    echo "**** install python packages ****" && \
    apt-get install -y --no-install-recommends python3-dev gcc libssl-dev libffi-dev && \
    CRYPTOGRAPHY_DONT_BUILD_RUST=1 \
    python3 -m pip install --no-cache-dir -r ${HOME}/requirements.txt && \
    apt-get purge -y --auto-remove python3-dev gcc libssl-dev libffi-dev && \
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

HEALTHCHECK --interval=30s --timeout=30s --start-period=50s --retries=3 CMD curl 127.0.0.1:$(sqlite3 ${HOME}/data/db/sjva.db "select value from system_setting where key='port'")/version || exit 1

VOLUME ${HOME}/data
WORKDIR ${HOME}/data
EXPOSE ${SJVA_PORT}

ENTRYPOINT ["/init"]
