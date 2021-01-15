ARG ALPINE_VER=3.13
ARG LIBTORRENT_VER=latest
FROM wiserain/libtorrent:${LIBTORRENT_VER}-alpine${ALPINE_VER}-py3 AS libtorrent
FROM ghcr.io/linuxserver/baseimage-alpine:${ALPINE_VER}
LABEL maintainer="wiserain"

# This hack is widely applied to avoid python printing issues in docker containers.
# See: https://github.com/Docker-Hub-frolvlad/docker-alpine-python3/pull/13
ENV PYTHONUNBUFFERED=1

# SYSTEM ENVs
ENV PATH="${PATH}:/app/data/bin:/app/data/command"
ENV PYTHONPATH "/app"
ENV SJVA_RUNNING_TYPE "docker"

# USER ENVs
ENV RCLONE_CONFIG=/app/data/db/rclone.conf
ENV TZ=Asia/Seoul

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
    echo "**** install sjva-deps ****" && \
    apk add --no-cache \
        py3-gevent \
        py3-lxml \
        py3-multidict \
        py3-pillow \
        py3-psutil \
        py3-pycryptodome \
        py3-yarl && \
    pip install -r /tmp/requirements.txt && \
    curl -fsSL https://filebrowser.org/get.sh | bash && \
    curl -fsSL https://raw.githubusercontent.com/wiserain/rclone/mod/install.sh | bash && \
    echo "**** cleanup ****" && \
    rm -rf \
        /tmp/* \
        /root/.cache \
        /var/cache/apk/*

# copy libtorrent libs
COPY --from=libtorrent /libtorrent-build/usr/lib/ /usr/lib/

RUN \
    echo "**** install sjva ****" && \
    git clone https://github.com/soju6jan/sjva2_src_obfuscate /app --depth=1

# copy local files
COPY root/ /

HEALTHCHECK --interval=30s --timeout=30s --start-period=50s --retries=3 CMD [ "curl 127.0.0.1:$(sqlite3 /app/data/db/sjva.db "select value from system_setting where key='port'")/version || exit 1" ]

WORKDIR /app/data
EXPOSE 9998 9999

ENTRYPOINT ["/init"]
