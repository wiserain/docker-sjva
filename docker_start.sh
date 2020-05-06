#!/bin/sh

git reset --hard HEAD
git pull
chmod 777 /app/*.sh
dos2unix /app/start.sh
sh /app/start.sh
