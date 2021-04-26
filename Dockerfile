FROM ghcr.io/wiserain/libtorrent:latest-ubuntu20.04-py3 AS libtorrent
FROM ghcr.io/linuxserver/baseimage-ubuntu:focal
LABEL maintainer="wiserain"
LABEL org.opencontainers.image.source https://github.com/wiserain/docker-sjva

ARG DEBIAN_FRONTEND="noninteractive"
ARG APT_MIRROR="archive.ubuntu.com"

COPY requirements.txt /tmp/

RUN \
    echo "**** prepare apt-get ****" && \
    sed -i "s/archive.ubuntu.com/\"$APT_MIRROR\"/g" /etc/apt/sources.list && \
    apt-get update -yqq && apt-get install -yqq --no-install-recommends apt-utils && \
    echo "**** install apt packages ****" && \
    apt-get install -y --no-install-recommends \
        `# python3` \
        python3 \
        python3-dev \
        python3-pip \
        python3-setuptools \
        python3-wheel \
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
        sqlite \
        jq \
        vnstat \
        `# torrent_info` \
        'libboost-python[0-9.]+$' && \
    sed -i 's/#user_allow_other/user_allow_other/' /etc/fuse.conf && \
    echo "**** install python packages ****" && \
    apt-get install -y --no-install-recommends \
        python3-gevent \
        python3-lxml \
        python3-multidict \
        python3-pil \
        python3-psutil \
        python3-yarl && \
    python3 -m pip install --no-cache-dir -r /tmp/requirements.txt && \
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

# SYSTEM ENVs
ENV PYTHONPATH "/app"
ENV TZ=Asia/Seoul
ENV SJVA_RUNNING_TYPE="docker"
ENV S6_BEHAVIOUR_IF_STAGE2_FAILS=2

# USER ENVs
ENV RCLONE_CONFIG=/app/data/db/rclone.conf
ENV PATH="/app/data/command:/app/data/bin:${PATH}"

# copy local files
COPY root/ /

HEALTHCHECK --interval=30s --timeout=30s --start-period=50s --retries=3 CMD curl 127.0.0.1:$(sqlite3 /app/data/db/sjva.db "select value from system_setting where key='port'")/version || exit 1

VOLUME /app/data
WORKDIR /app/data
EXPOSE 9998 9999

ENTRYPOINT ["/init"]
