ARG ALPINE_VER=3.10
ARG LIBTORRENT_VER=2.0.0
FROM wiserain/libtorrent:${LIBTORRENT_VER}-alpine${ALPINE_VER}-py2 AS libtorrent
FROM python:2.7-alpine${ALPINE_VER}
LABEL maintainer="wiserain"

# https://discordapp.com/channels/590210675628834846/619765438837948456/655753524378075147

ENV PYTHONWARNINGS="ignore:DEPRECATION::pip._internal.cli.base_command"
ENV PATH="${PATH}:/app/bin/Linux:/app/data/bin:/app/data/command"
ENV LANG=C.UTF-8
ENV PS1="\u@\h:\w\\$ "
ENV RCLONE_CONFIG=/app/data/db/rclone.conf
ENV PYTHONPATH "/app"
ENV SJVA_RUNNING_TYPE "docker"
ENV TZ=Asia/Seoul

COPY requirements.txt /tmp/

RUN \
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
        wget && \
    sed -i 's/#user_allow_other/user_allow_other/' /etc/fuse.conf && \
    echo "**** install build packages ****" && \
    apk add --no-cache --virtual build-deps \
        build-base \
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

COPY docker_start.sh /app
RUN chmod +x /app/docker_start.sh

HEALTHCHECK --interval=30s --timeout=30s --start-period=50s --retries=3 CMD [ "curl 127.0.0.1:$(sqlite3 /app/data/db/sjva.db "select value from system_setting where key='port'")/version || exit 1" ]

WORKDIR /app
EXPOSE 9998 9999

ENTRYPOINT ["/app/docker_start.sh"]
