# Debian GNOME Headless Docker Image

Welcome to the **Debian GNOME Headless Docker Image**! This minimal yet fully-featured Debian container comes with the **GNOME Desktop Environment** pre-installed, optimized for headless use cases. Whether you need a remote GNOME environment or just want to run GNOME apps via VNC, this image provides the essential tools with an easy setup.

[Docker Hub - nagamuslim/debian-gnome-headless](https://hub.docker.com/repository/docker/nagamuslim/debian-gnome-headless)

## Based on [minimum2scp](https://hub.docker.com/u/minimum2scp)
---

## Key Features

- **GNOME Desktop Environment**: Provides the full GNOME desktop experience in a headless setup.
- **Flatpak Support**: Easily run Flatpak apps, with Flathub remote pre-configured.
- **Pre-installed Software**: Includes essential software like **Firefox**, **VLC**, **yt-dlp**, and more.
- **VNC & noVNC Access**: Access the desktop environment remotely via **VNC** or a browser-based interface with **noVNC**.
- **Dark Mode**: The GNOME desktop environment has support to use to use dark mode

---

## Features Included

- **GNOME Desktop**: Includes GNOME settings, GNOME terminal, and other essential desktop utilities.
- **Flatpak**: Full Flatpak support with the **Flathub** repository already added.
- **VNC & Web-based Access**:
  - **Port 5901**: For traditional **VNC** access.
  - **Port 6901**: For **noVNC** (web-based VNC).
- **Pre-installed Software**:
  - **Firefox** for browsing.
  - **VLC** for media playback.
  - **yt-dlp** for downloading YouTube videos.
  - **p7zip** for file compression.

---

## How to Run

To run the container, use the following Docker command:

```bash
docker run --privileged -d -p 2022:22 -p 5901:5901 -p 6901:6901 nagamuslim/debian-gnome-headless

## Default Credentials

- **VNC Password**: `debian`
- **SSH Login**: Use SSH to log in with the username `debian` and password `debian`.

## Roadmap

This image is actively maintained, with the following priorities:

- Fix **GNOME Terminal** (High Priority)
- Fix **GNOME Software for Flatpak** (High Priority)
- Fix or **Remove Lock Screen** (High Priority)
- Added support for **Nix Package Manager**
- Added asia region mirror
- **Indonesian Language Support**
- **Audio Support**
- **Chrome Remote Desktop Integration**
- Switch to **X11VNC** 
