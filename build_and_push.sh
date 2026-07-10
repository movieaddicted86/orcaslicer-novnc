#!/bin/bash

image="ghcr.io/movieaddicted86/orcaslicer-novnc"

# Set the timestamp
timestamp=$(date +%Y.%m.%d.%H%M%S)

tag=$image:$timestamp
latest=$image:latest

# Build the image -- tagged with the timestamp.
docker build -t $tag -t $latest .

# Push with the timestamped tag, and latest image tag to the registry.
docker login ghcr.io
docker push $tag
docker push $latest

# Cleanup
docker system prune -f
