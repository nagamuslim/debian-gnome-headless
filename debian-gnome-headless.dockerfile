FROM minimum2scp/systemd:latest

#RUN chmod 777 /home/debian
##&& curl -O "https://downloads.realvnc.com/download/file/vnc.files/VNC-Server-7.13.1-Linux-x64.deb?lai_vid=EW33V2yA4ue2y&lai_sr=0-4"
 #&& mkdir -p /home/debian/.config && mkdir -p /home/debian/.cache && chmod 777 /home/debian/.config && chmod 777 /home/debian/.cache

RUN chmod 777 /home/debian && sed -i '/#deb-src.*sid/s/^#\s*//g' /etc/apt/sources.list && apt-get update -y && apt-get --yes --force-yes -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" upgrade -y && apt-get --yes --force-yes -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" dist-upgrade -y && \
    apt remove sysvinit-core initscripts sysv-rc sysvinit-utils -y --allow-remove-essential && \
    apt update -y && apt install expect systemd-container openssh-server htop systemd-sysv libpam-systemd systemd  -y && systemctl mask systemd-modules-load.service
#ENV remove="gnome-software gnome-shell-extensions gnome-terminal"
RUN apt-get update && HOME=/home/debian apt-get install -y \
    python3 \
    python3-pip \
    python3-websockify \
    novnc \
    nginx-extras \
    nginx \
    libfuse2 \
    tigervnc-standalone-server \
    $(apt show gnome-core | sed -n '/^Depends: /{:a;N;/\n[^ ]/!ba;s/\n[^ ].*$//;s/^Depends: //;p}' | sed 's/ ([^)]*)//g;s/[,\|]/ /g;s/  */ /g;s/ $//' | \tr ' ' '\n' | grep -v '^pipewire-audio$' | tr '\n' ' ' | sed 's/ $//') \
    $(apt show gnome-core | sed -n '/^Recommends: /{p;:a;n;/^ /{p;ba}}' | tr '\n' ' ' | sed -E 's/^Recommends: //;s/ \([^)]*\)//g;s/[|,]/ /g;s/ +/ /g;s/^ //;s/ $//' | tr ' ' '\n' | grep -v 'www' | grep -v 'chromium' | grep -v '^firefox-esr$' | tr '\n' ' ' | sed 's/ $//') \
    $(apt show gnome-core | sed -n '/^Suggests: /{p;:a;n;/^ /{p;ba}}' | tr '\n' ' ' | sed -E 's/^Suggests: //;s/ \([^)]*\)//g;s/[|,]/ /g;s/ +/ /g;s/^ //;s/ $//' | tr ' ' '\n' | sed 's/ $//') \
    $(apt show gnome | sed -n '/^Depends: /{p;:a;n;/^ /{p;ba}}' | tr '\n' ' ' | sed -E 's/^Depends: //;s/ \([^)]*\)//g;s/[|,]/ /g;s/ +/ /g;s/^ //;s/ $//' | tr ' ' '\n' | grep -v '^gnome-core$' | tr '\n' ' ' | sed 's/ $//') \
    $(apt show gnome | sed -n '/^Recommends: /{p;:a;n;/^ /{p;ba}}' | tr '\n' ' ' | sed -E 's/^Recommends: //;s/ \([^)]*\)//g;s/[|,]/ /g;s/ +/ /g;s/^ //;s/ $//' | tr ' ' '\n' | tr '\n' ' ' | sed 's/ $//') \
    $(apt show gnome | sed -n '/^Suggests: /{p;:a;n;/^ /{p;ba}}' | tr '\n' ' ' | sed -E 's/^Suggests: //;s/ \([^)]*\)//g;s/[|,]/ /g;s/ +/ /g;s/^ //;s/ $//' | tr ' ' '\n' | grep -v '^firefox-.*-all$' | grep -v '^webext-ublock-origin-chromium$' | tr '\n' ' ' | sed 's/ $//') \
    pulseaudio \
    pavucontrol \
    icecast2 \
    wget \
    gnome-settings-* \
    $(apt list gnome-shell-* | cut -d'/' -f1 | grep gnome- | grep -v 'gnome-shell-extension-gamemode' | grep -v 'gnome-shell-extension-weather' | \grep -v 'gnome-shell-extension-panel-osd' | grep -v 'gnome-shell-extension-vertical-overview' | tr '\n' ' ') \
    xfce4-terminal \
    nano \
    vlc \
    ffmpeg \
    yt-dlp \
    p7zip-full \
    p7zip-rar \
    butt \
    flatseal \
    xfce-polkit \
    dbus-x11 && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

ENV REMOVE_PACKAGES="gnome-software gnome-shell-extensions gnome-terminal"

# Use apt-get in a single RUN command for efficiency
# This also includes proper cleanup to reduce image size
RUN apt-get remove -y --purge $REMOVE_PACKAGES && \
    apt-get autoremove -y && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

RUN flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo && \
    systemctl set-default graphical.target && usermod -aG pulse-access root && usermod -aG pulse-access debian && \
    sed -i 's/<source-password>hackme<\/source-password>/<source-password>debian<\/source-password>/g' /etc/icecast2/icecast.xml && sed -i 's/<relay-password>hackme<\/relay-password>/<relay-password>debian<\/relay-password>/g' /etc/icecast2/icecast.xml && sed -i 's/<admin-password>hackme<\/admin-password>/<admin-password>debian<\/admin-password>/g' /etc/icecast2/icecast.xml && \
    HOME=/home/debian apt update && apt --no-install-recommends install plasma-discover-backend-flatpak plasma-discover -y
USER debian
RUN mkdir -p /home/debian/.vnc && \
    echo "debian" | vncpasswd -f > /home/debian/.vnc/passwd && \
    chmod 600 /home/debian/.vnc/passwd && echo 'if [ -z "$TERM" ] || [ "$TERM" = "unknown" ]; then export TERM="xterm-256color"; fi' >> /home/debian/.bashrc && \
    echo -e "\n#This is a configuration file for butt (broadcast using this tool)\n\n[main]\nbg_color = 252645120\ntxt_color = -256\nserver = icecast\nsrv_ent = icecast\nicy =\nicy_ent =\nnum_of_srv = 1\nnum_of_icy = 0\nsong_update_url_active = 0\nsong_update_url_interval = 1\nsong_update_url =\nsong_path =\nsong_update = 0\nsong_delay = 0\nsong_prefix =\nsong_suffix =\nread_last_line = 0\napp_update_service = 0\napp_update = 0\napp_artist_title_order = 1\ngain = 1.000000\nsignal_threshold = 0.000000\nsilence_threshold = 0.000000\nsignal_detection = 0\nsilence_detection = 0\ncheck_for_update = 1\nstart_agent = 0\nminimize_to_tray = 0\nconnect_at_startup = 1\nforce_reconnecting = 0\nreconnect_delay = 1\nic_charset =\nlog_file =\n\n[audio]\ndevice = 0\ndevice2 = -1\ndev_remember = 1\nsamplerate = 48000\nbitrate = 128\nchannel = 2\nleft_ch = 1\nright_ch = 2\nleft_ch2 = 1\nright_ch2 = 2\ncodec = opus\nresample_mode = 1\nsilence_level = 50.000000\nsignal_level = 50.000000\ndisable_dithering = 0\nbuffer_ms = 50\ndev_name = Default PCM device (default)\ndev2_name = None\n\n[record]\nbitrate = 192\ncodec = opus\nstart_rec = 0\nstop_rec = 0\nrec_after_launch = 0\noverwrite_files = 0\nsync_to_hour  = 0\nsplit_time = 0\nfilename = rec_%Y%m%d-%H%M%S.opus\nsignal_threshold = 0.000000\nsilence_threshold = 0.000000\nsignal_detection = 0\nsilence_detection = 0\nfolder = /home/debian/\n\n[tls]\ncert_file =\ncert_dir =\n\n[dsp]\nequalizer = 0\nequalizer_rec = 0\neq_preset = Manual\ngain1 = 0.000000\ngain2 = 0.000000\ngain3 = 0.000000\ngain4 = 0.000000\ngain5 = 0.000000\ngain6 = 0.000000\ngain7 = 0.000000\ngain8 = 0.000000\ngain9 = 0.000000\ngain10 = 0.000000\ncompressor = 0\ncompressor_rec = 0\naggressive_mode = 0\nthreshold = -20.000000\nratio = 5.000000\nattack = 0.010000\nrelease = 1.000000\nmakeup_gain = 0.000000\n\n[mixer]\nprimary_device_gain = 1.000000\nprimary_device_muted = 0\nsecondary_device_gain = 1.000000\nsecondary_device_muted = 0\nstreaming_gain = 1.000000\nrecording_gain = 1.000000\nrecording_muted = 0\n\n[stream]\nstream_title = \nstream_desc = \nstream_url = \nstream_genre = \n\n[web]\nweb_port = 1256\nweb_refresh_rate = 1\nweb_user = admin\nweb_password = admin\n\n" > /home/debian/butt.txt && \
    echo -e "#This is a configuration file for butt (broadcast using this tool)\n\n[main]\nbg_color = 252645120\ntxt_color = -256\nserver = web\nsrv_ent = web\nicy = \nicy_ent = \nnum_of_srv = 1\nnum_of_icy = 0\nsong_update_url_active = 0\nsong_update_url_interval = 1\nsong_update_url =\nsong_path = \nsong_update = 0\nsong_delay = 0\nsong_prefix = \nsong_suffix = \nread_last_line = 0\napp_update_service = 0\napp_update = 0\napp_artist_title_order = 1\ngain = 1.000000\nsignal_threshold = 0.000000\nsilence_threshold = 0.000000\nsignal_detection = 0\nsilence_detection = 0\ncheck_for_update = 1\nstart_agent = 0\nminimize_to_tray = 1\nconnect_at_startup = 1\nforce_reconnecting = 1\nreconnect_delay = 5\nic_charset = \nlog_file = \n\n[audio]\ndevice = 0\ndevice2 = -1\ndev_remember = 1\nsamplerate = 48000\nbitrate = 128\nchannel = 2\nleft_ch = 1\nright_ch = 2\nleft_ch2 = 1\nright_ch2 = 2\ncodec = opus\nresample_mode = 1\nsilence_level = 50.000000\nsignal_level = 50.000000\ndisable_dithering = 0\nbuffer_ms = 50\ndev_name = Default PCM device (default)\ndev2_name = None\n\n[record]\nbitrate = 192\ncodec = opus\nstart_rec = 0\nstop_rec = 0\nrec_after_launch = 0\noverwrite_files = 0\nsync_to_hour = 0\nsplit_time = 0\nfilename = rec_%Y%m%d-%H%M%S.opus\nsignal_threshold = 0.000000\nsilence_threshold = 0.000000\nsignal_detection = 0\nsilence_detection = 0\nfolder = /home/debian/\n\n[tls]\ncert_file = \ncert_dir = \n\n[dsp]\nequalizer = 0\nequalizer_rec = 0\neq_preset = Manual\ngain1 = 0.000000\ngain2 = 0.000000\ngain3 = 0.000000\ngain4 = 0.000000\ngain5 = 0.000000\ngain6 = 0.000000\ngain7 = 0.000000\ngain8 = 0.000000\ngain9 = 0.000000\ngain10 = 0.000000\ncompressor = 0\ncompressor_rec = 0\naggressive_mode = 0\nthreshold = -20.000000\nratio = 5.000000\nattack = 0.010000\nrelease = 1.000000\nmakeup_gain = 0.000000\n\n[mixer]\nprimary_device_gain = 1.000000\nprimary_device_muted = 0\nsecondary_device_gain = 1.000000\nsecondary_device_muted = 0\nstreaming_gain = 1.000000\nrecording_gain = 1.000000\nrecording_muted = 0\n\n[stream]\nstream_title = \nstream_desc = \nstream_url = \nstream_genre = \n\n[web]\nweb_port = 1257\nweb_refresh_rate = 1\nweb_user = admin\nweb_password = admin\n\n" > /home/debian/buttweb.txt && \
    cat > ~/.vnc/xstartup <<'END_SCRIPT'
#!/bin/sh
#exec >> /home/debian/xstartup.log 2>&1
#set -x

[ -r $HOME/.Xresources ] && xrdb $HOME/.Xresources
test x"$SHELL" = x"" && SHELL=/bin/bash
test x"$1" = x"" && set -- default
xhost +

#sudo -u debian -i bash -x >>/home/debian/xstartup.log 2>&1 <<'EOF'
sudo -u debian -i bash <<'EOF'
export DISPLAY=:1
export G_MESSAGES_DEBUG=all
export XAUTHORITY=/home/debian/.Xauthority

# System readiness detection function
detect_butt() {
    # Wait until AppImage appears (system is fully initialized)
    while ! find /usr/local/bin -maxdepth 1 -name 'butt*.AppImage' -print -quit | grep -q .; do
        sleep 5
    done
}

vncconfig -iconic &

# Configure GNOME
gsettings set org.gnome.shell favorite-apps "['firefox.desktop', 'org.gnome.Evolution.desktop', 'org.gnome.Nautilus.desktop', 'org.kde.discover.desktop', 'xfce4-terminal.desktop', 'org.gnome.TextEditor.desktop', 'org.gnome.Calculator.desktop']"
gsettings set org.gnome.desktop.session idle-delay 0
gsettings set org.gnome.desktop.screensaver lock-enabled false
gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark'

# Start base butt service
butt -c /home/debian/butt.txt >/dev/null 2>&1 &

# --- Split operations using detection function ---

# 1. Keyring removal operation
(detect_butt  && sleep 5 && rm -f ~/.local/share/keyrings/login.keyring ) &

# 2. AppImage launch operation
( detect_butt  && sleep 10 && /usr/local/bin/butt*.AppImage -c /home/debian/buttweb.txt & ) &
#find /usr/local/bin -maxdepth 1 -name 'butt*.AppImage' -exec {} -c /home/debian/buttweb.txt \; -quit >/dev/null 2>&1 &
( detect_butt && sleep 10 && /usr/libexec/gnome-initial-setup & ) &
# 3. Future operations can be added here
# detect_butt && your-custom-command

# Start desktop environment
export XDG_SESSION_TYPE=x11
exec gnome-session
EOF

vncserver -kill $DISPLAY
END_SCRIPT
RUN chmod u+x ~/.vnc/xstartup && mkdir -p /home/debian/Downloads /home/debian/.cache /home/debian/.config /home/debian/.local /home/debian/.gnupg /home/debian/Desktop && \
    sudo chmod 700 /home/debian/.gnupg /home/debian/.local && echo -e "\n[Backends]\nEnabledBackends=flatpak-backend\n\n[FlatpakSources]\nSources=flathub\n\n[PackageKit]\nEnabled=false\n\n[ResourcesModel]\ncurrentApplicationBackend=flatpak-backend" > /home/debian/.config/discoverrc && sed -i '/-e/d' /home/debian/.config/discoverrc && sed -i '/-e/d' /home/debian/.vnc/xstartup && \
    sudo chmod 755 /home/debian/.config && sudo chmod 777 /home/debian/.cache && sudo chmod u+rw  /home/debian/.cache/ && \
#COPY *.desktop /home/debian/Desktop/
    curl -o /home/debian/.cache/res.sh https://raw.githubusercontent.com/nagamuslim/debian-gnome-headless/main/res.sh && curl -o /home/debian/.cache/installer.py https://raw.githubusercontent.com/nagamuslim/debian-gnome-headless/main/installer.py && curl -o /home/debian/mediamtx.yml https://raw.githubusercontent.com/nagamuslim/debian-gnome-headless/main/mediamtx.yml && \
    sudo chmod +x /home/debian/.cache/installer.py && sudo chmod +x /home/debian/.cache/res.sh  && \
    mkdir -p ~/.config/tigervnc && cp ~/.vnc/* ~/.config/tigervnc/ && sudo chmod 755 /home/debian && sudo cp /home/debian/mediamtx.yml /mediamtx.yml 
USER root
RUN ln -s /home/debian/Downloads /mnt1 && sed -i '/@include common-auth/a auth       optional   pam_gnome_keyring.so' /etc/pam.d/login && sed -i '/@include common-session/a session    optional   pam_gnome_keyring.so auto_start' /etc/pam.d/login
WORKDIR /mnt1
RUN mkdir /etc/gnome-initial-setup/ 

RUN sudo mkdir -p /etc/polkit-1/rules.d && \
    echo 'polkit.addRule(function(action, subject) {' > /tmp/rule.js && \
    echo '    return polkit.Result.YES;' >> /tmp/rule.js && \
    echo '});' >> /tmp/rule.js && \
    sudo mv /tmp/rule.js /etc/polkit-1/rules.d/49-nopasswd-flatpak.rules

RUN mkdir -p /var/lib/systemd/linger \
    && touch /var/lib/systemd/linger/debian \
    && set -eux; \
    for svc in \
        pipewire.service \
        pipewire-pulse.service \
        wireplumber.service \
        pulseaudio.service \
        pipewire.socket \
        pipewire-pulse.socket \
        pulseaudio.socket \
    ; do \
        XDG_RUNTIME_DIR=/run/user/2000 \
        runuser -u debian -- systemctl --user mask "$svc"; \
    done; \
    echo "User services masked successfully." 
RUN curl -L  'https://raw.githubusercontent.com/nagamuslim/debian-gnome-headless/main/vendor.conf'   -o /etc/gnome-initial-setup/vendor.conf && curl -L  'https://raw.githubusercontent.com/nagamuslim/debian-gnome-headless/main/nginx.conf'   -o /etc/nginx/conf.d/default.conf
RUN set -eux; \
    \
    mkdir -p /home/debian/.ssh /root/.ssh; \
    \
    ssh-keygen -t ed25519 \
      -C "debian-to-ubuntu-key" \
      -f /home/debian/.ssh/id_ed25519 \
      -N ""; \
    ssh-keygen -t ed25519 \
      -C "root-to-ubuntu-key" \
      -f /root/.ssh/id_ed25519 \
      -N ""; \
    \
    cat /root/.ssh/id_ed25519.pub \
        /home/debian/.ssh/id_ed25519.pub \
      > /mnt1/test.txt; \
    \
    chown -R debian:debian /home/debian/.ssh; \
    chmod 700 /home/debian/.ssh; \
    chmod 600 /home/debian/.ssh/id_ed25519; \
    chmod 644 /home/debian/.ssh/id_ed25519.pub
RUN echo "app='$(curl -s https://api.github.com/repos/bluenviron/mediamtx/releases/latest | jq -r '.assets[] | select(.name | test("mediamtx_v.*_linux_amd64\\.tar\\.gz$")) | .browser_download_url') https://danielnoethen.de/butt/release/1.45.0/butt-1.45.0-x86_64.AppImage'" | sudo tee /etc/installer.env && \
    sed -i.bak '/<\/head>/i\ \ \ \ <script src="novnc-mediamtx-audio.js" defer><\/script>' /usr/share/novnc/vnc.html && curl -L   'https://raw.githubusercontent.com/nagamuslim/debian-gnome-headless/main/novnc-mediamtx-audio.js'  -o /usr/share/novnc/novnc-mediamtx-audio.js && \
    echo "load-module module-simple-protocol-tcp listen=127.0.0.1 format=s16le channels=2 rate=48000 record=true playback=true auth-anonymous=1" >> /etc/pulse/system.pa && sed -i '/-e/d' /home/debian/butt.txt || true && \
    echo -e "\n[Unit]\nDescription=Start TightVNC server at startup\nAfter=network.target\n\n[Service]\nType=forking\nUser=debian\nGroup=debian\nWorkingDirectory=/home/debian\nEnvironmentFile=-/run/vnc.env\nEnvironment=EDITOR=nano\nEnvironment=HOME=/home/debian\nEnvironment=USER=debian\nEnvironment=DISPLAY=:1\n\nPIDFile=/home/debian/.vnc/%H:%i.pid\nExecStartPre=+/home/debian/.cache/res.sh\nExecStart=/usr/bin/vncserver -geometry ${GEOMETRY} -depth 24 -localhost :%i\n\nExecStop=/usr/bin/vncserver -kill :%i\nExecStopPost=/bin/rm -f /home/debian/.vnc/%H:%i.pid\nTimeoutStartSec=infinity\nTimeoutStopSec=infinity\n[Install]\nWantedBy=multi-user.target" > /etc/systemd/system/vncserver@.service && \
    echo -e "[Unit]\nDescription=noVNC WebSocket Proxy Service\nAfter=network.target\n\n[Service]\nType=simple\nUser=debian\nGroup=debian\nWorkingDirectory=/home/debian\nEnvironment=HOME=/home/debian\nEnvironment=USER=debian\nExecStart=/usr/bin/websockify --web /usr/share/novnc 6080 localhost:5901\nRestart=always\nRestartSec=3\nStandardOutput=syslog\nStandardError=syslog\n\n[Install]\nWantedBy=multi-user.target" | sudo tee /etc/systemd/system/websockify.service > /dev/null && \
    echo -e "[Unit]\nDescription=Sound Service\n\n[Service]\n# Note that notify will only work if --daemonize=no\nType=notify\nExecStart=/usr/bin/pulseaudio --daemonize=no --exit-idle-time=-1 --disallow-exit=true --system --log-target=syslog --log-level=4\nNice=-10\nRestart=always\n\n[Install]\nWantedBy=default.target" > /etc/systemd/system/pulseaudio.service && \
    echo -e "\n[Unit]\nDescription=Dynamic Application Installer Service\nAfter=network-online.target \n\n[Service]\nType=simple\nWorkingDirectory=/home/debian/.cache/\nUser=debian\nGroup=debian\nEnvironmentFile=-/etc/installer.env\nEnvironment=app\nExecStart=/home/debian/.cache/installer.py\nExecStartPost=+/bin/rm -rf /etc/installer.env\nExecStartPost=-/usr/local/bin/mediamtx\nRestart=always\nTimeoutStopSec=infinity\nRestartSec=10\n\n[Install]\nWantedBy=multi-user.target" | sudo tee /etc/systemd/system/installer.service > /dev/null && \
    echo -e "\n[Unit]\nDescription=MediaMTX + BUTT Streaming Service\nAfter=network-online.target installer.service\nWants=installer.service network-online.target\n\n[Service]\nType=simple\nExecStart=/usr/local/bin/mediamtx \nRestart=on-failure\nRestartSec=2\nTimeoutStopSec=infinity\n\n[Install]\nWantedBy=multi-user.target" > /etc/systemd/system/mediamtx.service && \
    echo -e "\n[Unit]\nDescription=IBus Input Method Framework\nAfter=graphical-session.target\n\n[Service]\nType=dbus\nBusName=org.freedesktop.IBus\nExecStart=/usr/bin/ibus-daemon --xim --panel disable\nRestart=on-failure\n\n[Install]\nWantedBy=gnome-session.target" > /etc/systemd/user/ibus-daemon.service

#RUN tee /etc/systemd/user/ibus-daemon.service > /dev/null << 'EOF'
#    [Unit]
#    Description=IBus Input Method Framework
#    After=graphical-session.target
#
#    [Service]
#    Type=dbus
#    BusName=org.freedesktop.IBus
#    ExecStart=/usr/bin/ibus-daemon --xim --panel disable
#    Restart=on-failure
#
#    [Install]
#    WantedBy=gnome-session.target
#    EOF

RUN sed -i '/-e/d' /etc/systemd/user/ibus-daemon.service && sed -i '/-e/d' /etc/systemd/system/vncserver@.service && sudo sed -i 's|\(ExecStart=.*-geometry\) *|\1 ${GEOMETRY} |' /etc/systemd/system/vncserver@.service && \
    systemctl --user enable ibus-daemon && systemctl enable vncserver@1.service && systemctl enable pulseaudio.service && systemctl enable nginx && \
    systemctl enable websockify.service && systemctl enable icecast2 & dpkg --add-architecture i386 && apt update && \
    systemctl enable installer.service && systemctl enable mediamtx.service && sed -i '/-e/d' /etc/systemd/system/installer.service || true && sed -i '/-e/d' /etc/systemd/system/mediamtx.service || true
EXPOSE 22 5901 6080 6901 8000 8080 8888 8889
ENV DISPLAY=:1
ENV EDITOR=nano
ENTRYPOINT ["/opt/init-wrapper/sbin/entrypoint.sh"]
CMD ["/sbin/init"]
