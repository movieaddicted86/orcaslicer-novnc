# Get and install Easy noVNC.
FROM golang:1.25-trixie AS easy-novnc-build
WORKDIR /src
RUN go mod init build && \
    go get github.com/geek1011/easy-novnc@v1.1.0 && \
    go build -o /bin/easy-novnc github.com/geek1011/easy-novnc

# OrcaSlicer's AppImages are built for Ubuntu 24.04, so we base on the same to
# keep the runtime libraries compatible.
FROM ubuntu:24.04

# Optionally pin a specific OrcaSlicer release (e.g. v2.4.2). Empty = latest.
ARG ORCA_VERSION=""

ENV DEBIAN_FRONTEND=noninteractive \
    LANG=en_US.UTF-8

# Desktop, VNC and the handful of tools we want available inside the session.
# Kept intentionally lean: openbox as the WM, a file manager, a terminal, a
# browser for surfing, plus OrcaSlicer's runtime libraries.
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        # Core: VNC, window manager, process supervisor, privilege drop
        supervisor openbox tigervnc-standalone-server gosu \
        # Usability: file manager, terminal, browser, monitor, editor.
        # epiphany-browser (GNOME Web) is WebKit-based and reuses the same
        # libwebkit2gtk that OrcaSlicer needs, so it adds almost no image weight
        # and avoids Ubuntu's snap-only Firefox packaging.
        pcmanfm lxterminal epiphany-browser htop nano \
        # System basics
        ca-certificates curl jq xdg-utils locales fonts-dejavu-core \
        libgl1-mesa-dri \
        # OrcaSlicer runtime libraries (most are bundled in the AppImage, these
        # cover the common host-side gaps for GTK3/WebKit/GStreamer/GL)
        libgtk-3-0t64 libwebkit2gtk-4.1-0 libgstreamer1.0-0 \
        libgstreamer-plugins-base1.0-0 gstreamer1.0-gtk3 libglu1-mesa \
        libglew2.2 libosmesa6 libsecret-1-0 libnotify4 libspnav0 && \
    rm -rf /var/lib/apt/lists/* && \
    locale-gen en_US.UTF-8

# Install OrcaSlicer from its Linux AppImage.
WORKDIR /orca
COPY get_latest_orcaslicer_release.sh /orca/
RUN chmod +x /orca/get_latest_orcaslicer_release.sh && \
    orcaUrl=$(/orca/get_latest_orcaslicer_release.sh url "${ORCA_VERSION}") && \
    orcaName=$(/orca/get_latest_orcaslicer_release.sh name "${ORCA_VERSION}") && \
    echo "Downloading OrcaSlicer: ${orcaName}" && \
    curl -sSL "${orcaUrl}" -o "/orca/${orcaName}" && \
    chmod +x "/orca/${orcaName}" && \
    "/orca/${orcaName}" --appimage-extract && \
    mv /orca/squashfs-root /opt/OrcaSlicer && \
    rm -f "/orca/${orcaName}" /orca/*.json && \
    ln -s /opt/OrcaSlicer/AppRun /usr/local/bin/orca-slicer

# Create an unprivileged user and wire up the config/prints directories.
RUN groupadd orca && \
    useradd -g orca --create-home --home-dir /home/orca orca && \
    mkdir -p /configs/.config /prints && \
    ln -s /configs/.config /home/orca/.config && \
    echo 'XDG_DOWNLOAD_DIR="/prints/"' > /home/orca/.config/user-dirs.dirs && \
    echo 'file:///prints prints' > /home/orca/.gtk-bookmarks && \
    chown -R orca:orca /home/orca /configs /prints

COPY --from=easy-novnc-build /bin/easy-novnc /usr/local/bin/
COPY menu.xml /etc/xdg/openbox/
COPY supervisord.conf /etc/

EXPOSE 8080
VOLUME /configs/
VOLUME /prints/

# /configs/ holds OrcaSlicer's settings, /prints/ holds STL/GCODE files.
CMD ["bash", "-c", "chown -R orca:orca /configs/ /home/orca/ /prints/ && exec gosu orca supervisord -c /etc/supervisord.conf"]
