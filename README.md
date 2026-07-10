# OrcaSlicer noVNC Docker Container

## Overview

This is a lean noVNC build using supervisor to serve [OrcaSlicer](https://github.com/SoftFever/OrcaSlicer) in your favorite web browser. Just hop into a browser, slice, and upload your favorite 3D prints — no local install required.

> **Note:** This project originally shipped SuperSlicer (as `superslicer-novnc`). Since SuperSlicer is no longer actively maintained, it now runs the actively-developed **OrcaSlicer** and has been renamed accordingly.

The desktop session is intentionally kept slim: [Openbox](http://openbox.org/) as the window manager plus a file manager, terminal, and a browser for surfing — everything you need to work with, nothing you don't.

## How to use

To run this image:

```bash
docker run --detach \
  --volume=orcaslicer-novnc-data:/configs/ \
  --volume=orcaslicer-novnc-prints:/prints/ \
  -p 8080:8080 \
  --name=orcaslicer-novnc \
  ghcr.io/movieaddicted86/orcaslicer-novnc:latest
```

This binds `/configs/` in the container to a local volume named `orcaslicer-novnc-data` (holds OrcaSlicer's settings), binds `/prints/` to `orcaslicer-novnc-prints` (your STL/GCODE files, also the browser's download target), and exposes the noVNC web UI on port `8080`. Then open `http://<host>:8080` in a browser.

### Pinning an OrcaSlicer version

By default the image builds against the latest OrcaSlicer release. To pin a specific version, pass the `ORCA_VERSION` build arg:

```bash
docker build --build-arg ORCA_VERSION=v2.4.2 -t orcaslicer-novnc .
```

### Security note

The noVNC/VNC session has **no authentication** by design (intended for a trusted LAN or behind an authenticating reverse proxy). Do **not** expose port 8080 directly to the internet.

### GPU Acceleration/Passthrough

Like other Docker containers, you can pass an Nvidia GPU into the container using the `NVIDIA_VISIBLE_DEVICES` and `NVIDIA_DRIVER_CAPABILITIES` env vars, e.g. `-e NVIDIA_DRIVER_CAPABILITIES="all" -e NVIDIA_VISIBLE_DEVICES="all"`. Only tested on Nvidia GPUs.

## Links

[OrcaSlicer](https://github.com/SoftFever/OrcaSlicer)

[Supervisor](http://supervisord.org/)

[easy-novnc](https://github.com/geek1011/easy-novnc)
