# docker-sjva

Unofficial docker image for running SJVA

## Usage

```yaml
version: '2.4'

services:

  sjva:
    image: wiserain/sjva:latest
    # image: ghcr.io/wiserain/sjva:latest        # mirror
    container_name: sjva
    restart: always
    # restart: 'no'
    network_mode: bridge
    ports:
      - "9999:9999"
    environment:
      - TZ=Asia/Seoul
    privileged: true                             # only when rclone mount used
    sysctls:
      net.core.somaxconn: '511'                  # To resolve warning
    volumes:
      - ${DOCKER_ROOT}/sjva/data:/app/data
    mem_limit: 768m                              # If you want to limit memory usage
    # logging options
    logging:
      driver: json-file
      options:
        max-size: "1024k"
        max-file: "5"
```

## 이미지 특징

- ubuntu 20.04 기반
- [s6-overlay](https://github.com/just-containers/s6-overlay)를 이용하여 서비스 관리
- export.sh을 사용하지 않고 모든 것을 컨테이너 환경 변수로 대체
- 컨테이너 시작시 동작하는 유용한 기능 추가(아래 상세 내용 참고)

## 앱 현황

| 이름 | 종류 | 참고 |
|--|--|--|
| sqlite3 | apt |  |
| jq | apt |  |
| vnstat | apt | vnStat 플러그인 |
| ffmpeg | apt | vod/tv 플러그인 |
| libtorrent | 외부 | torrent_info 플러그인 |
| rclone | 외부 | [mod 버전](https://github.com/wiserain/rclone/releases) |
| [filebrowser](https://github.com/filebrowser/filebrowser/releases) | 외부 | 설치는 기본, 실행은 선택 |

상세한 내역은 [Dockerfile](https://github.com/wiserain/docker-sjva/blob/master/Dockerfile)과 [requirements.txt](https://github.com/wiserain/docker-sjva/blob/master/requirements.txt)에서 확인할 수 있음.

## 환경변수

미칠 영향을 알지 못하면 기본값을 변경하지 말 것. 변경하면 컨테이너를 다시 올려야 합니다. 컨테이너 중지 > 삭제 > 시작

### 시스템

컨테이너 환경 설정에 대한 변수들

| 이름 | 기본값 | 참고 |
|--|--|--|
| `PUID` / `PGID` | `0` / `0` | 앱을 non-root로 실행 (experimental) |
| `TZ` | `Asia/Seoul` | 타임존 |

### SJVA - 실행

SJVA 실행에 관여하는 환경 변수. `export.sh`를 사용하지 않고 컨테이너 환경 변수만으로 조정.

| 이름 | 기본값 | 참고 |
|--|--|--|
| `SJVA_PORT` | `9999` |  |
| `REDIS_PORT` | `46379` |  |
| `USE_CELERY` | `true` |  |
| `USE_GEVENT` | `true` |  |
| `CELERY_WORKER_COUNT` | `2` | 동시 실행 가능 프로세스 수 |
| `CELERY_VERBOSE` | `2` | 컨테이너로 전달되는 celery 로그. <br>`0`: quiet `1`: stderr only `2`: stderr+stdout |
| `CELERY_OPTS` |  | celery에 직접 전달되는 추가 인자. <br>예를 들면, `--loglevel=WARNING` |

### 추가기능 - 패키지 설치

패키지 이름을 `|`로 구분된 문자열로 입력하면 시작 시에 설치를 보장함. 예를들어 `INSTALL_PIP_PKGS=transmissionrpc|youtube_dl`를 입력하면

```bash
pip install transmissionrpc youtube_dl
```

를 root 권한으로 실행함.

| 이름 | 기본값 | 참고 |
|--|--|--|
| `INSTALL_APT_PKGS` |  | apt-get install을 실행 |
| `INSTALL_PIP_PKGS` |  | pip install을 실행 |

### 추가기능 - 마운트/파일/폴더 체크

경로를 `|`로 구분된 문자열로 입력하면 시작 시에 마운트/파일/폴더의 존재를 확인. 없으면 무제한 대기

| 이름 | 기본값 | 참고 |
|--|--|--|
| `WAIT_RCLONE_MNTS` |  | rclone 마운트 경로 |
| `WAIT_MFS_MNTS` |  | mergerfs 마운트 경로 |
| `WAIT_ANCHOR_DIRS` |  | 폴더 경로 |
| `WAIT_ANCHOR_FILES` |  | 파일 경로 |

### 추가기능 - 기타

컨테이너 (재)시작시 한번만 실행되며 값을 입력하지 않으면 적용하지 않음.

| 이름 | 기본값 | 참고 |
|--|--|--|
| `USE_FILEBROWSER` |  | 파일브라우저를 함께 실행하려면 `true` |
| `FB_BASEURL` | `/` | baseurl |
| `FB_DATABASE` | `/app/data/db/filebrowser.db` | path to db |
| `FB_PORT` | `9998` | port to open |
| `FB_ROOT` | `/` | root path |
| `APT_MIRROR` | `archive.ubuntu.com` | apt repository 주소 변경 |

`FB_`로 시작하는 환경변수는 filebrowser에서 직접 지원하는 변수로 [링크](https://filebrowser.org/cli/filebrowser)를 참고.

## Handling Warnings

### vm.overcommit_memory

```bash
# WARNING overcommit_memory is set to 0! Background save may fail under low memory condition. To fix this issue add 'vm.overcommit_memory = 1' to /etc/sysctl.conf and then reboot or run the command 'sysctl vm.overcommit_memory=1' for this to take effect.
```

### Transparent Huge Pages (THP)

```bash
# WARNING you have Transparent Huge Pages (THP) support enabled in your kernel. This will create latency and memory usage issues with Redis. To fix this issue run the command 'echo never > /sys/kernel/mm/transparent_hugepage/enabled' as root, and add it to your /etc/rc.local in order to retain the setting after a reboot. Redis must be restarted after THP is disabled.
```

add followings to crontab, then reboot

```bash
@reboot echo never > /sys/kernel/mm/transparent_hugepage/enabled
@reboot echo never > /sys/kernel/mm/transparent_hugepage/defrag
```
