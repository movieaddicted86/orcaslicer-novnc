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

### GPU Passthrough

The image ships the drivers to pass an **Nvidia, Intel or AMD** GPU into the container. How you pass it in depends on the vendor (below).

> **What this does — and does not — accelerate.** OrcaSlicer renders its 3D view
> through the noVNC session's *virtual* X server (TigerVNC), which only offers
> software GLX. So the **viewport itself is rendered on the CPU (`llvmpipe`)
> regardless of the GPU you pass in** — running `glxinfo` will report `llvmpipe`,
> not your card. Passing a GPU still gives you compute visibility (`nvidia-smi`),
> Vulkan, and hardware video decode (VA-API) for the built-in browser. True
> hardware-accelerated OpenGL for the viewport would require VirtualGL, which this
> image does not (yet) integrate. For OrcaSlicer's moderate 3D needs, `llvmpipe`
> on a decent CPU is usually fine.

#### Nvidia

Requires the [Nvidia Container Toolkit](https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/latest/install-guide.html) on the host. Pass the GPU with `--gpus`, or with the `NVIDIA_VISIBLE_DEVICES` / `NVIDIA_DRIVER_CAPABILITIES` env vars:

```bash
docker run -d -p 8080:8080 \
  --gpus all \
  -e NVIDIA_VISIBLE_DEVICES=all \
  -e NVIDIA_DRIVER_CAPABILITIES=all \
  -v orcaslicer-novnc-data:/configs/ \
  -v orcaslicer-novnc-prints:/prints/ \
  --name orcaslicer-novnc \
  ghcr.io/movieaddicted86/orcaslicer-novnc:latest
```

#### Intel / AMD

These use the host's DRI render nodes via Mesa (iris for Intel, radeonsi for AMD — already in the image). Pass `/dev/dri` in as a device. If the container's `render` group GID doesn't match the host's, also grant access with `--group-add`:

```bash
docker run -d -p 8080:8080 \
  --device /dev/dri:/dev/dri \
  --group-add "$(getent group render | cut -d: -f3)" \
  -v orcaslicer-novnc-data:/configs/ \
  -v orcaslicer-novnc-prints:/prints/ \
  --name orcaslicer-novnc \
  ghcr.io/movieaddicted86/orcaslicer-novnc:latest
```

To confirm the GPU reached the container, run `nvidia-smi` (Nvidia) or `ls /dev/dri` (Intel/AMD) in the session's terminal. Note that `glxinfo` will still report `llvmpipe` for the viewport — see the note above.

## Links

[OrcaSlicer](https://github.com/SoftFever/OrcaSlicer)

[Supervisor](http://supervisord.org/)

[easy-novnc](https://github.com/geek1011/easy-novnc)
