ARG UBUNTU_VER=20.04

FROM ghcr.io/by275/libtorrent:latest-ubuntu${UBUNTU_VER} AS libtorrent
FROM ghcr.io/by275/base:ubuntu${UBUNTU_VER} AS prebuilt
FROM ghcr.io/linuxserver/baseimage-ubuntu:focal AS base

ARG DEBIAN_FRONTEND="noninteractive"
ARG APT_MIRROR="archive.ubuntu.com"

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

# 
# BUILD
# 
FROM base AS builder

ARG DEBIAN_FRONTEND="noninteractive"

COPY requirements.txt /tmp/

RUN \
    echo "**** prepare apt-get ****" && \
    apt-get update -yqq
RUN echo "**** install depencencies for psutil ****" && \
    apt-get install -y --no-install-recommends \
        python3-dev gcc
RUN echo "**** install pip packages ****" && \
    python3 -m pip install --root=/bar -r /tmp/requirements.txt --no-warn-script-location

# add local files
COPY root/ /bar/

ADD https://raw.githubusercontent.com/by275/docker-base/main/_/etc/cont-init.d/install-pkg /bar/etc/cont-init.d/30-install-pkg
ADD https://raw.githubusercontent.com/by275/docker-base/main/_/etc/cont-init.d/wait-for-mnt /bar/etc/cont-init.d/40-wait-for-mnt
ADD https://raw.githubusercontent.com/by275/docker-base/main/_/etc/cont-init.d/90-custom-folders /bar/etc/cont-init.d/90-custom-folders
ADD https://raw.githubusercontent.com/by275/docker-base/main/_/etc/cont-init.d/99-custom-scripts /bar/etc/cont-init.d/99-custom-scripts

# copy libtorrent libs
COPY --from=libtorrent /libtorrent-build/usr/lib/ /bar/usr/lib/
# copy docker-cli
COPY --from=prebuilt /docker-cli/ /bar/

# 
# RELEASE
# 
FROM base
LABEL maintainer="wiserain"
LABEL org.opencontainers.image.source https://github.com/wiserain/docker-sjva

ARG DEBIAN_FRONTEND="noninteractive"

# SYSTEM ENVs
ENV S6_BEHAVIOUR_IF_STAGE2_FAILS=2 \
    PYTHONUNBUFFERED=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1 \
    PIP_NO_CACHE_DIR=1 \
    PUID=0 \
    PGID=0 \
    TZ=Asia/Seoul \
    HOME=/app \
    SJVA_RUNNING_TYPE=docker \
    SJVA_REPEAT_COUNT=0 \
    CELERY_APP=sjva3.celery \
    SJVA_PORT=9999 \
    REDIS_PORT=46379 \
    USE_CELERY=true \
    USE_GEVENT=true \
    CELERY_WORKER_COUNT=2 \
    PLUGIN_UPDATE_FROM_PYTHON=false \
    PATH="/app/data/command:/app/data/bin:/app/.local/bin:$PATH" \
    PYTHONPATH="${PYTHONPATH:+$PYTHONPATH:}/app"

# add build artifacts
COPY --from=builder /bar/ /

HEALTHCHECK --interval=30s --timeout=30s --start-period=50s --retries=3 \
    CMD curl -fsS -o /dev/null http://localhost:${SJVA_PORT}/version || exit 1

VOLUME /app/data
WORKDIR /app/data
EXPOSE ${SJVA_PORT}

ENTRYPOINT ["/init"]
