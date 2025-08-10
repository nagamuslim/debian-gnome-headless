
FROM minimum2scp/systemd:latest

RUN chmod 777 /home/debian 
#RUN echo -e "\nPackage: pipewire\nPin: release a=stable\nPin-Priority: -1\n\nPackage: pipewire-*\nPin: release a=stable\nPin-Priority: -1\n\nPackage: pipewire-alsa\nPin: release a=stable\nPin-Priority: -1\n\nPackage: pipewire-audio\nPin: release a=stable\nPin-Priority: -1\n\nPackage: pulseaudio\nPin: release a=stable\nPin-Priority: 1000" > /etc/apt/preferences.d/pipewire-blacklist && sed -i '/-e/d' /etc/apt/preferences.d/pipewire-blacklist
# Install essential packages and software
RUN sed -i '/#deb-src.*sid/s/^#\s*//g' /etc/apt/sources.list && \
    apt-get update && apt update && apt full-upgrade -y && HOME=/home/debian apt-get install -y \
    python3 \
    python3-pip \
    python3-websockify \
    novnc \
    tigervnc-standalone-server \
    $(apt show gnome-core | grep '^Depends:' | sed 's/^Depends: //; s/([^)]*)//g; s/,//g; s/|/ /g' | grep -v 'pipewire-audio' | tr -s ' ' ) \
    gnome-settings-* \
    gnome-terminal-* \
    $(apt list gnome-shell-* | cut -d'/' -f1 | grep gnome- | grep -v 'gnome-shell-extension-gamemode' | grep -v 'gnome-shell-extension-weather' | \grep -v 'gnome-shell-extension-panel-osd' | grep -v 'gnome-shell-extension-vertical-overview' | tr '\n' ' ') \
    gnome-software \
    $(apt-cache pkgnames gnome-software- | grep -v 'gnome-software-plugin-snap' | tr '\n' ' ') \
    xfce4-terminal \
    pulseaudio \
    libasound2-plugins \
    libpulsedsp \
    pulseaudio-utils \
    socat \
    gstreamer1.0-tools \
    gstreamer1.0-plugins-base \
    gstreamer1.0-plugins-good \
    pavucontrol \
    wget \
    gstreamer1.0-plugins-bad \
    dbus-x11 && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*


RUN flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
RUN HOME=/home/debian apt update && apt install nano vlc ffmpeg yt-dlp p7zip-full p7zip-rar -y
RUN systemctl set-default graphical.target
# RUN echo "load-module module-simple-protocol-tcp listen=127.0.0.1 format=s16le channels=2 rate=48000 record=true playback=false" > /etc/pulse/default.pa.d/simple-protocol.pa && echo -e "vnc: 127.0.0.1:5901\naudio: 127.0.0.1:5711" > /etc/websockify/token.cfg && sed -i '/<\/head>/i \ \ \ \ <script type="module" crossorigin="anonymous" src="audio-plugin.js"></script>' /usr/share/novnc/vnc.html






# Create VNC directory and set password for the non-root user
USER debian
RUN mkdir -p /home/debian/.vnc && \
    echo "debian" | vncpasswd -f > /home/debian/.vnc/passwd && \
    chmod 600 /home/debian/.vnc/passwd

# Set up VNC configuration
RUN echo -e "#!/bin/sh\n# Check if .Xresources exists and load it\n[ -r \$HOME/.Xresources ] && xrdb \$HOME/.Xresources\n\n# Set default shell to /bin/bash if not already set\ntest x\"\$SHELL\" = x\"\" && SHELL=/bin/bash\n\n# If no arguments are passed, set default session\ntest x\"\$1\" = x\"\" && set -- default\n\n# Start vncconfig in the background\nvncconfig -iconic &\n\n# Start a login shell and launch the desktop session\n\"\$SHELL\" -l <<EOF\nexport XDG_SESSION_TYPE=x11\ndbus-launch --exit-with-session gnome-session\nexec /etc/X11/Xsession \"\$@\"\nEOF\n\n# Stop the VNC server if needed\nvncserver -kill \$DISPLAY" > ~/.vnc/xstartup && chmod u+x ~/.vnc/xstartup
RUN mkdir -p /home/debian/.cache /home/debian/noVNC-audio-plugin /home/debian/.config /home/debian/.local /home/debian/.gnupg && sudo mkdir -p /etc/websockify && \
    sudo chmod 700 /home/debian/.gnupg /home/debian/.local && \
    sudo chmod 755 /home/debian/.config && sudo chmod 777 /home/debian/.cache && sudo chmod u+rw  /home/debian/.cache/


RUN sudo git clone https://github.com/me-asri/noVNC-audio-plugin.git /home/debian/noVNC-audio-plugin \
    && sudo mv /home/debian/noVNC-audio-plugin/audio-plugin.js /usr/share/novnc/ \
    && mv /home/debian/noVNC-audio-plugin/audio-proxy.sh /home/debian/.cache/ \
    && sudo rm -rf /home/debian/noVNC-audio-plugin

#RUN sudo echo "load-module module-simple-protocol-tcp listen=127.0.0.1 format=s16le channels=2 rate=48000 record=true playback=false" > /etc/pulse/default.pa.d/simple-protocol.pa && sudo echo -e "vnc: 127.0.0.1:5901\naudio: 127.0.0.1:5711" > /etc/websockify/token.cfg && sudo sed -i '/<\/head>/i \ \ \ \ <script type="module" crossorigin="anonymous" src="audio-plugin.js"></script>' /usr/share/novnc/vnc.html
RUN echo -e "pulseaudio -k &\npulseaudio --start &\ngst-launch-1.0 -v tcpclientsrc host=127.0.0.1 port=4711 ! audioconvert ! lamemp3enc ! filesink location=/home/debian/Music/audio.mp3 &" > /home/debian/.cache/audio.sh && sudo chmod +x /home/debian/.cache/audio.sh && sudo chmod +x /home/debian/.cache/audio-proxy.sh 
RUN sed -i '/-e/d' /home/debian/.cache/audio.sh 

RUN mkdir -p ~/.config/tigervnc && cp ~/.vnc/* ~/.config/tigervnc/ && sudo chmod 755 /home/debian

USER root

RUN echo "load-module module-simple-protocol-tcp listen=127.0.0.1 format=s16le channels=2 rate=48000 record=true playback=false" > /etc/pulse/default.pa.d/simple-protocol.pa && echo -e "vnc: 127.0.0.1:5901\naudio: 127.0.0.1:5711" > /etc/websockify/token.cfg && sed -i '/<\/head>/i \ \ \ \ <script type="module" crossorigin="anonymous" src="audio-plugin.js"></script>' /usr/share/novnc/vnc.html
RUN sed -i '/-e/d' /etc/pulse/default.pa.d/simple-protocol.pa && sed -i '/-e/d' /etc/websockify/token.cfg
RUN echo -e "[Unit]\nDescription=Start TightVNC server at startup\nAfter=network.target\n\n[Service]\nType=forking\nUser=debian\nGroup=debian\nWorkingDirectory=/home/debian\nEnvironment=HOME=/home/debian\nEnvironment=USER=debian\nEnvironment=DISPLAY=:1\n\nPIDFile=/home/debian/.vnc/%H:%i.pid\nExecStartPre=-/usr/bin/vncserver -kill :%i > /dev/null 2>&1\nExecStart=/usr/bin/vncserver -geometry 1280x720 -depth 24 -localhost :%i\nExecStop=/usr/bin/vncserver -kill :%i\nExecStopPost=/bin/rm -f /home/debian/.vnc/%H:%i.pid\nTimeoutStartSec=infinity\nTimeoutStopSec=infinity\n[Install]\nWantedBy=multi-user.target" > /etc/systemd/system/vncserver@.service
#RUN echo -e "[Unit]\nDescription=noVNC WebSocket Proxy Service\nAfter=network.target\n\n[Service]\nType=simple\nUser=debian\nGroup=debian\nWorkingDirectory=/home/debian\nEnvironment=HOME=/home/debian\nEnvironment=USER=debian\nExecStartPre=\home\debian\.cache\audio.sh\nExecStartPre=\home\debian\.cache\audio-proxy.sh -l 5711\nExecStart=/usr/bin/websockify --web /usr/share/novnc --token-plugin=TokenFile --token-source=/etc/websockify/token.cfg 6901\nRestart=always\nRestartSec=3\nStandardOutput=syslog\nStandardError=syslog\n\n[Install]\nWantedBy=multi-user.target" | sudo tee /etc/systemd/system/websockify.service > /dev/null
RUN echo -e "[Unit]\nDescription=noVNC WebSocket Proxy Service\nAfter=network.target\n\n[Service]\nType=simple\nUser=debian\nGroup=debian\nWorkingDirectory=/home/debian\nEnvironment=HOME=/home/debian\nEnvironment=USER=debian\nExecStartPre=/home/debian/.cache/audio.sh\nExecStartPre=/home/debian/.cache/audio-proxy.sh -l 5711\nExecStart=/usr/bin/websockify --web /usr/share/novnc --token-plugin=TokenFile --token-source=/etc/websockify/token.cfg 6901\nRestart=always\nRestartSec=3\nStandardOutput=syslog\nStandardError=syslog\n\n[Install]\nWantedBy=multi-user.target" | sudo tee /etc/systemd/system/websockify.service > /dev/null
#RUN echo -e "\n[Unit]\nDescription=Custom Post-VNC Setup Service\nAfter=network.target vncserver@1.service\n\n[Service]\nType=oneshot\nUser=debian\nGroup=debian\nWorkingDirectory=/home/debian\nEnvironment=DISPLAY=:1\nEnvironment=USER=debian\nExecStartPre=/bin/sleep 15\nExecStart=/bin/bash -c 'gsettings set org.gnome.desktop.interface \gtk-theme \"prefer-dark\"'\nExecStart=/bin/bash -c 'gsettings set org.gnome.desktop.session idle-delay 0'\nRemainAfterExit=true\nTimeoutStartSec=infinity\nTimeoutStopSec=infinity\n\n[Install]\nWantedBy=multi-user.target" > /etc/systemd/user/postvnc.service
#RUN sed '/-e/d' /etc/systemd/system/postvnc.service

RUN systemctl enable vncserver@1.service
#RUN systemctl enable postvnc.service
RUN systemctl enable websockify.service
#RUN sed -i '/-e/d' /etc/systemd/user/postvnc.service && systemctl enable vncserver@1.service && systemctl --user enable postvnc.service && systemctl enable websockify.service
# Expose VNC and noVNC ports
EXPOSE 22 5901 6901

# Set environment variables
ENV DISPLAY=:1
ENV PULSE_SERVER=unix:/tmp/pulse/native

# Set the entrypoint to the old script
ENTRYPOINT ["/opt/init-wrapper/sbin/entrypoint.sh"]

# Run VNC server and Websockify as the debian user, then initialize systemd
CMD ["/sbin/init"]
