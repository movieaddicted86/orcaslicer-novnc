# CLAUDE.md

Guidance for Claude Code when working in this repository.

## What this project is

A lean Docker image that serves [OrcaSlicer](https://github.com/SoftFever/OrcaSlicer)
(a 3D-printing slicer) in a web browser via noVNC — no local install required.
Users open `http://<host>:8080`, slice, and save GCODE straight to a mounted volume.

The project originally shipped **SuperSlicer** (`superslicer-novnc`). SuperSlicer is
no longer actively maintained, so it now runs the actively-developed **OrcaSlicer**
and was renamed accordingly. Expect stray `superslicer` references in history — the
current name is `orcaslicer-novnc`.

Published to `ghcr.io/movieaddicted86/orcaslicer-novnc`.

## Architecture

Everything runs in a single Ubuntu 24.04 container (chosen to match the distro
OrcaSlicer's AppImage is built against, keeping runtime libs compatible).
`supervisord` (see [supervisord.conf](supervisord.conf)) runs four programs:

| Program      | Role                                                        |
|--------------|-------------------------------------------------------------|
| `Xtigervnc`  | VNC server on port 5900, `SecurityTypes None` (no auth)     |
| `easy-novnc` | Web ↔ VNC bridge, exposes the UI on **port 8080**           |
| `openbox`    | Lightweight window manager (`DISPLAY=:0`)                   |
| `orca-slicer`| The app itself, `--datadir /configs/.config/OrcaSlicer/`    |

`easy-novnc` is a Go binary compiled in a multi-stage build step and copied into
the final image. The desktop session is intentionally minimal — Openbox plus a
file manager (pcmanfm), terminal (lxterminal), browser (epiphany, WebKit-based so
it reuses OrcaSlicer's libs), htop, and nano. Menu entries live in [menu.xml](menu.xml).

The container runs OrcaSlicer as an unprivileged `orca` user (via `gosu`); the
`CMD` first `chown`s the mounted volumes so the drop-in user can write to them.

## Key files

- [Dockerfile](Dockerfile) — the whole build; multi-stage (easy-novnc build → Ubuntu runtime).
- [supervisord.conf](supervisord.conf) — process definitions for the running container.
- [menu.xml](menu.xml) — Openbox right-click menu.
- [get_latest_orcaslicer_release.sh](get_latest_orcaslicer_release.sh) — resolves the
  x86_64 Linux AppImage download URL / filename from the GitHub releases API (uses `jq`,
  excludes the aarch64 asset). Called at build time.
- [build_and_push.sh](build_and_push.sh) — local manual build + push with a timestamp tag.
- [.github/workflows/docker-publish.yml](.github/workflows/docker-publish.yml) — CI.
- [renovate.json](renovate.json) — automated dependency updates.

## Volumes & ports

- `/configs/` — OrcaSlicer settings (symlinked to `/home/orca/.config`).
- `/prints/` — STL/GCODE files; also the browser's `XDG_DOWNLOAD_DIR`.
- Port `8080` — noVNC web UI.

## Build & release

- **CI:** [docker-publish.yml](.github/workflows/docker-publish.yml) builds on every push
  to `main`, pushes to GHCR, and signs the image with cosign. PRs build but do not push.
- **Pin an OrcaSlicer version:** pass the `ORCA_VERSION` build arg (e.g. `v2.4.2`).
  Empty (default) = latest release.
  ```bash
  docker build --build-arg ORCA_VERSION=v2.4.2 -t orcaslicer-novnc .
  ```
- **Local run:**
  ```bash
  docker run -d -p 8080:8080 \
    -v orcaslicer-novnc-data:/configs/ \
    -v orcaslicer-novnc-prints:/prints/ \
    --name orcaslicer-novnc \
    ghcr.io/movieaddicted86/orcaslicer-novnc:latest
  ```
- **GPU passthrough:** the image carries drivers for all three vendors so a GPU can
  be *passed in*, but see the hard limit below.
  - *Nvidia* — via the Nvidia Container Toolkit (`--gpus all` or
    `NVIDIA_VISIBLE_DEVICES` / `NVIDIA_DRIVER_CAPABILITIES`).
  - *Intel / AMD* — via the host render nodes: `--device /dev/dri` plus, if GIDs
    differ, `--group-add "$(getent group render | cut -d: -f3)"`. Mesa's iris/radeonsi
    drivers (in `libgl1-mesa-dri`) do the work; the `orca` user is in `video`/`render`.
  - **The 3D viewport is NOT GPU-accelerated.** OrcaSlicer draws through TigerVNC's
    virtual X server, which only offers software GLX — so `glxinfo` reports `llvmpipe`
    no matter which GPU is passed in. Passthrough still buys compute (`nvidia-smi`),
    Vulkan, and VA-API video decode for the browser. Hardware GL for the viewport
    would need VirtualGL (render on the GPU, blit into the VNC framebuffer), which is
    deliberately not integrated — the maintainer accepts `llvmpipe` for the viewport.
    Verified July 2026 on a native host + RTX A2000: `nvidia-smi` sees the card,
    `glxinfo` still shows `llvmpipe`. See [README](README.md#gpu-passthrough).

## Conventions & gotchas

- Keep the image **lean** — this is a stated project goal. Justify any new apt package;
  prefer libraries OrcaSlicer already needs over pulling in new dependency trees.
- Shell scripts are bash (`#!/bin/bash`), even though the dev machine is Windows/PowerShell.
  They run inside the Linux container / CI, not locally.
- **No authentication** on VNC/noVNC is by design (trusted LAN or behind an
  authenticating reverse proxy). Do not "fix" this by adding auth without discussion,
  and never suggest exposing 8080 to the internet.
- The Ubuntu base version is coupled to OrcaSlicer's AppImage target — don't bump it
  independently of what OrcaSlicer builds against.
