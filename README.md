# docker-sjva

Unofficial docker image for running SJVA

## Usage

```yaml
version: '2.4'

services:

  sjva:
    image: wiserain/sjva:latest
    container_name: sjva
    # restart: always
    restart: 'no'
    network_mode: bridge
    ports:
      - "9998:9998"                           # Optional if filebrowser used
      - "9999:9999"
    environment:
      - PUID=${PUID}
      - PGID=${PGID}
      - TZ=Asia/Seoul
      - FB_BASEURL=/filebrowser               # Optional if filebrowser used
    # privileged: true                        # only when rclone mount used
    sysctls:
      net.core.somaxconn: '511'                             # To resolve warning
    volumes:
      - ${DOCKER_ROOT}/sjva/data:/app/data
      - /var/lib/vnstat:/var/lib/vnstat:ro                  # Optional
    mem_limit: 768m                                         # If you want to limit memory usage
    # logging options
    logging:
      driver: json-file
      options:
        max-size: "1024k"
        max-file: "5"
```

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
