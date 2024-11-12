FROM minimum2scp/systemd:latest

# Install essential packages and software
RUN sed -i '/#deb-src.*sid/s/^#\s*//g' /etc/apt/sources.list && \
    apt-get update && apt update && apt full-upgrade -y && apt-get install -y \
    python3 \
    python3-pip \
    python3-websockify \
    novnc \
    tigervnc-standalone-server \
    task-gnome-desktop \
    gnome-settings-* \
    gnome-terminal-* \
    $(apt list gnome-shell-* | cut -d'/' -f1 | grep gnome- | grep -v 'gnome-shell-extension-gamemode' | grep -v 'gnome-shell-extension-weather' | \grep -v 'gnome-shell-extension-panel-osd' | grep -v 'gnome-shell-extension-vertical-overview' | tr '\n' ' ') \
    gnome-software \
    $(apt-cache pkgnames gnome-software- | grep -v 'gnome-software-plugin-snap' | tr '\n' ' ') \
    xfce4-terminal \
    dbus-x11 && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*


RUN flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
RUN apt update && apt install nano vlc ffmpeg yt-dlp p7zip-full p7zip-rar -y
RUN systemctl set-default graphical.target






# Create VNC directory and set password for the non-root user
USER debian
RUN mkdir -p /home/debian/.vnc && \
    echo "debian" | vncpasswd -f > /home/debian/.vnc/passwd && \
    chmod 600 /home/debian/.vnc/passwd

# Set up VNC configuration
RUN echo -e "#!/bin/sh\n# Check if .Xresources exists and load it\n[ -r \$HOME/.Xresources ] && xrdb \$HOME/.Xresources\n\n# Set default shell to /bin/bash if not already set\ntest x\"\$SHELL\" = x\"\" && SHELL=/bin/bash\n\n# If no arguments are passed, set default session\ntest x\"\$1\" = x\"\" && set -- default\n\n# Start vncconfig in the background\nvncconfig -iconic &\n\n# Start a login shell and launch the desktop session\n\"\$SHELL\" -l <<EOF\nexport XDG_SESSION_TYPE=x11\ndbus-launch --exit-with-session gnome-session\nexec /etc/X11/Xsession \"\$@\"\nEOF\n\n# Stop the VNC server if needed\nvncserver -kill \$DISPLAY" > ~/.vnc/xstartup && chmod u+x ~/.vnc/xstartup


USER root

RUN echo -e "[Unit]\nDescription=Start TightVNC server at startup\nAfter=network.target\n\n[Service]\nType=forking\nUser=debian\nGroup=debian\nWorkingDirectory=/home/debian\nEnvironment=HOME=/home/debian\nEnvironment=USER=debian\nEnvironment=DISPLAY=:1\n\nPIDFile=/home/debian/.vnc/%H:%i.pid\nExecStartPre=-/usr/bin/vncserver -kill :%i > /dev/null 2>&1\nExecStart=/usr/bin/vncserver -geometry 1280x720 -depth 24 -localhost :%i\nExecStop=/usr/bin/vncserver -kill :%i\nExecStopPost=/bin/rm -f /home/debian/.vnc/%H:%i.pid\n\n[Install]\nWantedBy=multi-user.target" > /etc/systemd/system/vncserver@.service
RUN echo -e "[Unit]\nDescription=noVNC WebSocket Proxy Service\nAfter=network.target\n\n[Service]\nType=simple\nUser=debian\nGroup=debian\nWorkingDirectory=/home/debian\nEnvironment=HOME=/home/debian\nEnvironment=USER=debian\nExecStart=/usr/bin/websockify --web /usr/share/novnc 6901 localhost:5901\nRestart=always\nRestartSec=3\nStandardOutput=syslog\nStandardError=syslog\n\n[Install]\nWantedBy=multi-user.target" | sudo tee /etc/systemd/system/websockify.service > /dev/null
RUN systemctl enable vncserver@1.service
RUN systemctl enable websockify.service

# Expose VNC and noVNC ports
EXPOSE 22 5901 6901

# Set environment variables
ENV DISPLAY=:1
ENV PULSE_SERVER=unix:/tmp/pulse/native

# Set the entrypoint to the old script
ENTRYPOINT ["/opt/init-wrapper/sbin/entrypoint.sh"]

# Run VNC server and Websockify as the debian user, then initialize systemd
CMD ["/sbin/init"]
