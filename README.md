# Debian GNOME Headless Docker Image

Welcome to the **Debian GNOME Headless Docker Image**! This fully-featured Debian container comes with the **GNOME Desktop Environment** pre-installed, optimized for headless use cases. Whether you need a remote GNOME environment or just want to run GNOME apps via VNC, this image provides the essential tools with an easy setup.

[Docker Hub - nagamuslim/debian-gnome-headless](https://hub.docker.com/repository/docker/nagamuslim/debian-gnome-headless)
Based on [minimum2scp](https://hub.docker.com/u/minimum2scp)
---

## Key Features

- **GNOME Desktop Environment**: Provides the full GNOME desktop experience in a headless setup.
- **Flatpak Support**: Easily run Flatpak apps, with Flathub remote pre-configured and managed via KDE Discover.
- **Audio Support**: Stream audio from the container to your browser via an integrated Icecast server.
- **Pre-installed Software**: Includes essential software like **Firefox**, **VLC**, **yt-dlp**, and more.
- **VNC & noVNC Access**: Access the desktop environment remotely via **VNC** or a browser-based interface with **noVNC**.
- **Customizable**: Extensive customization options available through environment variables.
- **Dark Mode**: The GNOME desktop environment has support to use to use dark mode

---

## Features Included

- **GNOME Desktop**: Includes GNOME settings and other essential desktop utilities. `XFCE4 Terminal` is used as the default terminal.
- **Flatpak**: Full Flatpak support with the **Flathub** repository already added. `KDE Discover` is included as a graphical frontend for managing Flatpak applications.

> **WARNING:** If you want to install Flatpak apps using the GUI, open Discover, go to settings, and click the star icon to make Flathub the default source.

- **VNC & Web-based Access**:
  - **Port 5901**: For traditional **VNC** access.
  - **Port 6901**: For **noVNC** (web-based VNC).
- **Pre-installed Software**:
  - **Firefox** for browsing.
  - **VLC** for media playback.
  - **yt-dlp** for downloading YouTube videos.
  - **p7zip** for file compression.
- **Lock Screen Disabled**: The lock screen is disabled by default for seamless remote access.
- **Configurable APT Mirror**: Switch to a Japanese APT mirror by setting the `APT_LINE` environment variable to `jp`.

---
## Default Credentials

- **VNC Password**: `debian`
- **SSH Login**: Use SSH to log in with the username `debian` and password `debian`.
---
## Roadmap

This image is actively maintained, with the following priorities:

- Added support for **Nix Package Manager**
- **Indonesian Language Support**
- **Chrome Remote Desktop Integration**
- Switch to **X11VNC**

---
## How to Run

> **TIP:** If the `docker run` command takes a long time, you can pull the image first using `docker pull nagamuslim/debian-gnome-headless`.

To run the container, use the following Docker command:

```bash
docker run --privileged -d -p 2022:22 -p 5901:5901 -p 6901:6901 -p 8000:8000 nagamuslim/debian-gnome-headless
```

### Environment Variables

You can customize the container by setting the following environment variables:

#### VNC and Application Installation

- `res`: Sets the VNC screen resolution (e.g., `1920x1080`, `1280x720`, or presets like `1080p`, `720p`).
- `VNC_PASSWORD`: Sets the VNC password. It's an alternative to `USER_PASSWORD`.
- `app`: A space-separated list of applications to install. This can include APT packages, Flatpak application IDs, or URLs to `.deb`, `.tar.gz`, or `.AppImage` files.

#### User and Group Management

- `CUSTOM_USER`: Any valid string for a username (e.g., `jdoe`).
- `CUSTOM_USER_PASSWORD`: Any string for the custom user's password.
- `CUSTOM_USER_SSH_KEY_URI`: A URL to a public SSH key (e.g., `https://example.com/key.pub`) or a GitHub username (e.g., `octocat`).
- `CUSTOM_GROUP`: Any valid string for a group name (e.g., `developers`).
- `CUSTOM_USER_UID`: A numerical user ID (e.g., `1001`).
- `CUSTOM_GROUP_GID`: A numerical group ID (e.g., `1001`).
- `CUSTOM_USER_GECOS`: A string for the user's information, often the full name (e.g., `"John Doe"`).
- `CUSTOM_USER_SHELL`: The path to a valid login shell (e.g., `/bin/bash` or `/bin/sh`).
- `USER_PASSWORD`: Any string for the default `debian` user's password.
- `USER_SSH_KEY_URI`: A URL to a public SSH key or a GitHub username for the `debian` user.
- `ROOT_PASSWORD`: Any string for the `root` user's password.
- `ROOT_SSH_KEY_URI`: A URL to a public SSH key or a GitHub username for the `root` user.

#### System Configuration (01-set-lang-and-tz)

- `DEFAULT_LANG`: A valid locale string (e.g., `en_US.UTF-8`).
- `DEFAULT_TZ`: A valid timezone string from the tz database (e.g., `Asia/Jakarta` or `Etc/UTC`).

#### Package Management (05-apt)

- `APT_LINE`:
  - `keep`: Uses the default Debian repository.
  - `jp`: Switches to the Japanese mirror.
  - A full repository URL (e.g., `http://deb.debian.org/debian/`).
- `APT_HTTP_PROXY`: A full proxy URL (e.g., `http://192.168.1.1:3142/`).
- `APT_UPDATE`: `yes`, `true`, `on`, or `1` to run `apt-get update`.
- `APT_INSTALL_PACKAGES`: A space-separated list of packages to install (e.g., `"nginx git curl"`).
- `APT_INSTALL_RECOMMENDS`: `yes`, `true`, `on`, or `1` to install recommended packages.
- `APT_INSTALL_SUGGESTS`: `yes`, `true`, `on`, or `1` to install suggested packages.

#### Software Installation (07-nginx, 07-docker-ce-cli)

- `INSTALL_NGINX`: `yes` to trigger the Nginx installation.
- `INSTALL_DOCKER_CE_CLI`: `yes` to trigger the Docker CE CLI installation.


<!-- To add an image to this README, place the image file in the 'images' directory and then use the following markdown syntax: ![alt text](images/your-image-filename.png) -->