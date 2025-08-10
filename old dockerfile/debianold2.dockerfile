# Use the base image
FROM minimum2scp/systemd:latest

# Install essential packages and software
RUN apt-get update && apt-get install -y \
    python3 \
    python3-pip \
    python3-websockify \
    novnc \
    tigervnc-standalone-server \
    task-gnome-desktop \
    gnome-settings-daemon \
    gnome-games \
    gnome-remote-desktop \
    gnome-software \
    flatpak \
    wget \
    zip \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Create a non-root user
#RUN useradd -m -s /bin/bash debian && echo "debian:debian" | chpasswd && adduser debian sudo

# Create VNC directory and set password for the non-root user
USER debian
RUN mkdir -p /home/debian/.vnc && \
    echo "debian" | vncpasswd -f > /home/debian/.vnc/passwd && \
    chmod 600 /home/debian/.vnc/passwd

# Set up VNC configuration
RUN echo "#!/bin/sh\nunset SESSION_MANAGER\nunset DBUS_SESSION_BUS_ADDRESS\nexec gnome-session " > /home/debian/.vnc/xstartup && \
    chmod +x /home/debian/.vnc/xstartup

# Set user back to root for further installations
USER root

# Expose VNC and noVNC ports
EXPOSE 5901 6901

# Setup environment for sound support
RUN apt-get update && apt-get install -y \
    pulseaudio \
    pavucontrol \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Set environment variables
ENV DISPLAY=:1
ENV PULSE_SERVER=unix:/tmp/pulse/native

# Create a script to run both entrypoints
RUN echo "#!/bin/bash\n\
# Run the original entrypoint as root in the background\n\
/opt/init-wrapper/sbin/entrypoint.sh & \n\
# Run VNC server and Websockify as the non-root user\n\
exec su - debian -c 'vncserver :1 -geometry 1280x720 -depth 24 && websockify --web /usr/share/novnc 6901 localhost:5901'" > /usr/local/bin/start.sh && \
    chmod +x /usr/local/bin/start.sh

# Set the entrypoint to systemd and the command to run the script
ENTRYPOINT ["/lib/systemd/systemd"]
CMD ["/usr/local/bin/start.sh"]
