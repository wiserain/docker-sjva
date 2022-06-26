#!/bin/bash
set -euo pipefail

IMAGE_NAME="wiserain/sjva"

if [ ${1:-load} = "push" ]; then
    docker buildx build \
        -t $IMAGE_NAME:latest \
        -t $IMAGE_NAME:latest-3.0 \
        -t ghcr.io/$IMAGE_NAME:latest \
        -t ghcr.io/$IMAGE_NAME:latest-3.0 \
        --platform=linux/amd64,linux/arm/v7,linux/arm64 \
        --push \
        .
    exit 0
fi

docker buildx build \
    -t $IMAGE_NAME:latest \
    -t $IMAGE_NAME:latest-3.0 \
    -t ghcr.io/$IMAGE_NAME:latest \
    -t ghcr.io/$IMAGE_NAME:latest-3.0 \
    --platform=linux/amd64,linux/arm/v7,linux/arm64 \
    .
