ARG ALPINE_VER=3.11
ARG LIBTORRENT_VER=2.0.0
FROM wiserain/libtorrent:${LIBTORRENT_VER}-alpine${ALPINE_VER}-py2 AS libtorrent
FROM lsiobase/alpine:${ALPINE_VER}
LABEL maintainer="wiserain"

# This hack is widely applied to avoid python printing issues in docker containers.
# See: https://github.com/Docker-Hub-frolvlad/docker-alpine-python3/pull/13
ENV PYTHONUNBUFFERED=1

ENV PYTHONWARNINGS="ignore:DEPRECATION::pip._internal.cli.base_command"

# SYSTEM ENVs
ENV PATH="${PATH}:/app/data/bin:/app/data/command"
ENV PYTHONPATH "/app"
ENV SJVA_RUNNING_TYPE "docker"

# USER ENVs
ENV RCLONE_CONFIG=/app/data/db/rclone.conf
ENV TZ=Asia/Seoul

COPY requirements.txt /tmp/

RUN \
    echo "**** install frolvlad/alpine-python2 ****" && \
    apk add --no-cache python2 && \
    python -m ensurepip && \
    rm -r /usr/lib/python*/ensurepip && \
    pip install --upgrade pip setuptools && \
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
    echo "**** install build packages ****" && \
    apk add --no-cache --virtual build-deps \
        build-base python2-dev musl-dev \
        `# pycrypto` \
        libffi-dev openssl-dev libc-dev \
        `# psutil` \
        linux-headers  \
        `# lxml` \
        libxml2-dev libxslt-dev \
        `# Pillow` \
        jpeg-dev zlib-dev && \
    echo "**** install python packages ****" && \
    pip install -r /tmp/requirements.txt && \
    echo "**** install runtime packages ****" && \
    apk add --no-cache \
        `# torrent_info` \
        libstdc++ boost-python2 boost-system \
        libxml2 \
        libxslt \
        jpeg && \
    echo "**** install built-in apps ****" && \
    curl -fsSL https://filebrowser.org/get.sh | bash && \
    curl -fsSL https://raw.githubusercontent.com/wiserain/rclone/mod/install.sh | bash && \
    echo "**** cleanup ****" && \
    apk del --purge --no-cache build-deps && \
    rm -rf \
        /tmp/* \
        /root/.cache \
        /var/cache/apk/*

# copy libtorrent libs
COPY --from=libtorrent /libtorrent-build/usr/lib/ /usr/lib/

RUN \
    echo "**** install sjva ****" && \
    git clone https://github.com/soju6jan/SJVA2 /app --depth=1

# copy local files
COPY root/ /

HEALTHCHECK --interval=30s --timeout=30s --start-period=50s --retries=3 CMD [ "curl 127.0.0.1:$(sqlite3 /app/data/db/sjva.db "select value from system_setting where key='port'")/version || exit 1" ]

WORKDIR /app/data
EXPOSE 9998 9999

ENTRYPOINT ["/init"]
