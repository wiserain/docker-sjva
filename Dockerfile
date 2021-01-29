ARG ALPINE_VER=3.13
ARG LIBTORRENT_VER=latest
FROM wiserain/libtorrent:${LIBTORRENT_VER}-alpine${ALPINE_VER}-py3 AS libtorrent
FROM ghcr.io/linuxserver/baseimage-alpine:${ALPINE_VER}
LABEL maintainer="wiserain"

# This hack is widely applied to avoid python printing issues in docker containers.
# See: https://github.com/Docker-Hub-frolvlad/docker-alpine-python3/pull/13
ENV PYTHONUNBUFFERED=1

COPY requirements.txt /tmp/

RUN \
    echo "**** install frolvlad/alpine-python3 ****" && \
    apk add --no-cache python3 && \
    if [ ! -e /usr/bin/python ]; then ln -sf /usr/bin/python3 /usr/bin/python; fi && \
    python3 -m ensurepip && \
    rm -r /usr/lib/python*/ensurepip && \
    pip3 install --no-cache --upgrade pip setuptools wheel && \
    if [ ! -e /usr/bin/pip ]; then ln -s pip3 /usr/bin/pip; fi && \
    echo "**** install core packages ****" && \
    apk add --no-cache \
        ffmpeg \
        git \
        redis \
        dos2unix \
        fuse \
        curl \
        tzdata \
        bash-completion \
        `# custom apks` \
        bash \
        procps \
        sqlite \
        coreutils \
        findutils \
        mediainfo \
        jq \
        unzip \
        vnstat \
        wget && \
    sed -i 's/#user_allow_other/user_allow_other/' /etc/fuse.conf && \
    echo "**** install python packages ****" && \
    apk add --no-cache \
        py3-gevent \
        py3-lxml \
        py3-multidict \
        py3-pillow \
        py3-psutil \
        py3-pycryptodome \
        py3-yarl && \
    pip install -r /tmp/requirements.txt && \
    echo "**** install runtime packages ****" && \
    apk add --no-cache \
        `# torrent_info` \
        libstdc++ boost-python3 boost-system && \
    echo "**** install built-in apps ****" && \
    curl -fsSL https://filebrowser.org/get.sh | bash && \
    curl -fsSL https://raw.githubusercontent.com/wiserain/rclone/mod/install.sh | bash && \
    echo "**** cleanup ****" && \
    rm -rf \
        /tmp/* \
        /root/.cache \
        /var/cache/apk/*

# copy libtorrent libs
COPY --from=libtorrent /libtorrent-build/usr/lib/ /usr/lib/

# SYSTEM ENVs
ENV PYTHONPATH "/app"
ENV TZ=Asia/Seoul
ENV SJVA_RUNNING_TYPE="docker"
ENV S6_BEHAVIOUR_IF_STAGE2_FAILS=2

# USER ENVs
ENV RCLONE_CONFIG=/app/data/db/rclone.conf
ENV PATH="/app/data/command:/app/data/bin:/app/bin:${PATH}"

# copy local files
COPY root/ /

HEALTHCHECK --interval=30s --timeout=30s --start-period=50s --retries=3 CMD curl 127.0.0.1:$(sqlite3 /app/data/db/sjva.db "select value from system_setting where key='port'")/version || exit 1

VOLUME /app/data
WORKDIR /app/data
EXPOSE 9998 9999

ENTRYPOINT ["/init"]
