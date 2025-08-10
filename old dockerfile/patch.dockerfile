FROM minimum2scp/systemd:latest

#RUN chmod 777 /home/debian
##&& curl -O "https://downloads.realvnc.com/download/file/vnc.files/VNC-Server-7.13.1-Linux-x64.deb?lai_vid=EW33V2yA4ue2y&lai_sr=0-4"
 #&& mkdir -p /home/debian/.config && mkdir -p /home/debian/.cache && chmod 777 /home/debian/.config && chmod 777 /home/debian/.cache

RUN chmod 777 /home/debian && sed -i '/#deb-src.*sid/s/^#\s*//g' /etc/apt/sources.list && apt-get update -y && apt-get --yes --force-yes -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" upgrade -y && apt-get --yes --force-yes -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" dist-upgrade -y && \
    apt remove sysvinit-core initscripts sysv-rc sysvinit-utils -y --allow-remove-essential && \
    apt update -y && apt install expect systemd-container openssh-server htop systemd-sysv libpam-systemd systemd  -y && systemctl mask systemd-modules-load.service

# Expose VNC and noVNC ports
EXPOSE 22 

# Set environment variables
ENV DISPLAY=:1
ENV EDITOR=nano

# Set the entrypoint to the old script
ENTRYPOINT ["/opt/init-wrapper/sbin/entrypoint.sh"]
#ENTRYPOINT ["/lib/systemd/systemd"]
# Run VNC server and Websockify as the debian user, then initialize systemd
CMD ["/lib/systemd/systemd"]
#CMD ["/sbin/init"]
