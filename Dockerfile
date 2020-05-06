ARG ALPINE_VER
ARG LIBTORRENT_VER
FROM wiserain/libtorrent:${LIBTORRENT_VER}-alpine${ALPINE_VER} AS libtorrent
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

RUN \
	echo "**** install core packages ****" && \
	apk add --no-cache \
		ffmpeg \
		git \
		vnstat \
		redis \
		dos2unix \
		fuse \
		curl \
		tzdata \
		bash-completion \
		`# custom apks` \
		bash \
		procps \
		coreutils \
		findutils \
		mediainfo \
		jq && \
	sed -i 's/#user_allow_other/user_allow_other/' /etc/fuse.conf && \
    cp /usr/share/zoneinfo/Asia/Seoul /etc/localtime && \
	echo "**** install build packages ****" && \
	apk add --no-cache --virtual build-deps \
		`# pycrypto` \
		gcc g++ make libffi-dev openssl-dev libc-dev \
		`# psutil` \
		linux-headers  \
		`# lxml` \
		libxml2-dev libxslt-dev \
		`# Pillow` \
		jpeg-dev zlib-dev && \
	echo "**** install python packages ****" && \
	pip install -r https://raw.githubusercontent.com/soju6jan/SJVA2/master/requirements.txt && \
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
COPY --from=libtorrent /libtorrent-py2/usr/lib/ /usr/lib/

RUN \
	echo "**** install sjva ****" && \
	git clone https://github.com/soju6jan/SJVA2 /app

COPY docker_start.sh /app
RUN chmod +x /app/docker_start.sh

WORKDIR /app
EXPOSE 9998 9999

ENTRYPOINT ["/app/docker_start.sh"]
