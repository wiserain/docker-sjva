FROM ghcr.io/wiserain/libtorrent:latest-ubuntu20.04 AS libtorrent

FROM ghcr.io/linuxserver/baseimage-ubuntu:focal AS base
FROM base AS builder

ADD https://raw.githubusercontent.com/by275/docker-scripts/master/root/etc/cont-init.d/20-install-pkg /bar/etc/cont-init.d/30-install-pkg
ADD https://raw.githubusercontent.com/by275/docker-scripts/master/root/etc/cont-init.d/30-wait-for-mnt /bar/etc/cont-init.d/40-wait-for-mnt
ADD https://raw.githubusercontent.com/by275/docker-scripts/master/root/etc/cont-init.d/90-custom-folders /bar/etc/cont-init.d/90-custom-folders
ADD https://raw.githubusercontent.com/by275/docker-scripts/master/root/etc/cont-init.d/99-custom-scripts /bar/etc/cont-init.d/99-custom-scripts

# copy libtorrent libs
COPY --from=libtorrent /libtorrent-build/usr/lib/ /bar/usr/lib/

# add local files
COPY root/ /bar/
COPY requirements.txt /tmp/

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
        python3-gevent
RUN echo "**** install depencencies for cffi cryptography ****" && \
    apt-get install -y --no-install-recommends \
        python3-dev gcc libssl-dev libffi-dev
RUN echo "**** install depencencies for lxml ****" && \
    apt-get install -y --no-install-recommends libxml2-dev libxslt1-dev
RUN echo "**** install depencencies for pil ****" && \
    apt-get install -y --no-install-recommends \
        libtiff5-dev libjpeg8-dev libopenjp2-7-dev zlib1g-dev \
        libfreetype6-dev liblcms2-dev libwebp-dev tcl8.6-dev tk8.6-dev python3-tk \
        libharfbuzz-dev libfribidi-dev libxcb1-dev
RUN echo "**** install pip packages ****" && \
    CRYPTOGRAPHY_DONT_BUILD_RUST=1 \
    python3 -m pip install --root=/bar -r /tmp/requirements.txt --no-warn-script-location
RUN echo "**** install docker-ce-cli ****" && \
    apt-get install -y --no-install-recommends \
        ca-certificates \
        curl \
        gnupg \
        lsb-release && \
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg && \
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null && \
    apt-get update && apt-get install -y --no-install-recommends docker-ce-cli && \
    mkdir /bar/usr/bin -p && mv /usr/bin/docker /bar/usr/bin/

# 
# release
# 
FROM base
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
    PATH="$HOME/data/command:$HOME/data/bin:$HOME/.local/bin:$PATH" \
    PYTHONPATH="${PYTHONPATH:+$PYTHONPATH:}$HOME"

# add build artifacts
COPY --from=builder /bar/ /

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
        `# python3` \
        libxml2 libxslt1.1 \
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

HEALTHCHECK --interval=30s --timeout=30s --start-period=50s --retries=3 \
    CMD curl 127.0.0.1:$(sqlite3 ${HOME}/data/db/sjva.db "select value from system_setting where key='port'")/version || exit 1

VOLUME ${HOME}/data
WORKDIR ${HOME}/data
EXPOSE ${SJVA_PORT}

ENTRYPOINT ["/init"]
