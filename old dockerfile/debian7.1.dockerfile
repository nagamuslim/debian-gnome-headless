#FROM minimum2scp/systemd:latest
FROM test:latest
#RUN chmod 777 /home/debian 
##&& curl -O "https://downloads.realvnc.com/download/file/vnc.files/VNC-Server-7.13.1-Linux-x64.deb?lai_vid=EW33V2yA4ue2y&lai_sr=0-4"
 #&& mkdir -p /home/debian/.config && mkdir -p /home/debian/.cache && chmod 777 /home/debian/.config && chmod 777 /home/debian/.cache

#RUN sed -i '/#deb-src.*sid/s/^#\s*//g' /etc/apt/sources.list && apt-get update -y && apt-get --yes --force-yes -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" upgrade -y && apt-get --yes --force-yes -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" dist-upgrade -y
#ENV test="gnome-software gnome-shell-extensions gnome-terminal gnome-console"
# Install essential packages and software
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
    $(apt show gnome-core | sed -n '/^Suggests: /{p;:a;n;/^ /{p;ba}}' | tr '\n' ' ' | sed -E 's/^Suggests: //;s/ \([^)]*\)//g;s/[|,]/ /g;s/ +/ /g;s/^ //;s/ $//' | tr ' ' '\n' | grep -v '^gnome$' | tr '\n' ' ' | sed 's/ $//') \
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

#    $(apt-cache pkgnames gnome-software- | grep -v 'gnome-software-plugin-snap' | tr '\n' ' ') 
#RUN apt-get remove -y --purge $remove && \
#  apt-get autoremove -y 
# Define the environment variable for the packages to remove
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

#RUN echo -e "[general]\nduration      = 0          # 0 means stream forever\nbufferSecs    = 5          # buffer for the input, in seconds\nreconnect     = yes        # reconnect to the server(s) if disconnected\n\n[input]\ndevice        = pulse                 # Use PulseAudio input driver\npaSourceName  = auto_null.monitor   # Specific PulseAudio source: Monitor of Dummy Output\nsampleRate    = 44100               # sample rate in Hz (corrected typo and value)\nbitsPerSample = 16                  # bits per sample. try 16\nchannel       = 2                   # channels. 1 = mono, 2 = stereo\n\n# This section describes the server connection for the first Icecast server.\n# There can be up to 8 of these sections, named [icecast2-0] ... [icecast2-7]\n#\n[icecast2-0]\nbitrateMode   = cbr        # Constant Bit Rate mode (or vbr for variable)\nformat        = mp3        # Audio format - requires LAME library installed and compiled in darkice\nbitrate       = 128        # bitrate in kbps\nserver        = localhost  # server name or IP\nport          = 8000       # port number\npassword      = debian     # Source password for Icecast\nmountPoint    = mystream   # mount point on the server (e.g. /live.mp3)\nname          = My Stream  # name of the stream\ndescription   = My live stream description # description of the stream\nurl           = http://mywebsite.com # URL related to the stream\ngenre         = myGenre    # genre of the stream\npublic        = no         # yes means listing on public lists (like Icecast directory)\nlocalDumpFile = /home/debian/Downloads/dump.mp3 # Record to local file" > /etc/darkice.cfg


#RUN chown -R debian:debian /home/debian/.* && chown -R debian:debian /home/debian && chmod 755 /home/debian 
#RUN printf -v butt_content "%s\n" "#This is a configuration file for butt (broadcast using this tool)" "" "[main]" "bg_color = 252645120" "txt_color = -256" "server = icecast" "srv_ent = icecast" "icy =" "icy_ent =" "num_of_srv = 1" "num_of_icy = 0" "song_update_url_active = 0" "song_update_url_interval = 1" "song_update_url =" "song_path =" "song_update = 0" "song_delay = 0" "song_prefix =" "song_suffix =" "read_last_line = 0" "app_update_service = 0" "app_update = 0" "app_artist_title_order = 1" "gain = 1.000000" "signal_threshold = 0.000000" "silence_threshold = 0.000000" "signal_detection = 0" "silence_detection = 0" "check_for_update = 1" "start_agent = 0" "minimize_to_tray = 0" "connect_at_startup = 0" "force_reconnecting = 0" "reconnect_delay = 1" "ic_charset =" "log_file =" "" "[audio]" "device = 0" "device2 = -1" "dev_remember = 1" "samplerate = 44100" "bitrate = 128" "channel = 2" "left_ch = 1" "right_ch = 2" "left_ch2 = 1" "right_ch2 = 2" "codec = opus" "resample_mode = 1" "silence_level = 50.000000" "signal_level = 50.000000" "disable_dithering = 0" "buffer_ms = 50" "dev_name = Default PCM device (default)" "dev2_name = None" "" "[record]" "bitrate = 192" "codec = opus" "start_rec = 0" "stop_rec = 0" "rec_after_launch = 0" "overwrite_files = 0" "sync_to_hour  = 0" "split_time = 0" "filename = rec_%Y%m%d-%H%M%S.opus" "signal_threshold = 0.000000" "silence_threshold = 0.000000" "signal_detection = 0" "silence_detection = 0" "folder = /home/debian/" "" "[tls]" "cert_file =" "cert_dir =" "" "[dsp]" "equalizer = 0" "equalizer_rec = 0" "eq_preset = Manual" "gain1 = 0.000000" "gain2 = 0.000000" "gain3 = 0.000000" "gain4 = 0.000000" "gain5 = 0.000000" "gain6 = 0.000000" "gain7 = 0.000000" "gain8 = 0.000000" "gain9 = 0.000000" "gain10 = 0.000000" "compressor = 0" "compressor_rec = 0" "aggressive_mode = 0" "threshold = -20.000000" "ratio = 5.000000" "attack = 0.010000" "release = 1.000000" "makeup_gain = 0.000000" "" "[mixer]" "primary_device_gain = 1.000000" "primary_device_muted = 0" "secondary_device_gain = 1.000000" "secondary_device_muted = 0" "streaming_gain = 1.000000" "recording_gain = 1.000000" "cross_fader = 0.000000" "" "[gui]" "attach = 0" "ontop = 0" "hide_log_window = 0" "remember_pos = 1" "x_pos = 425" "y_pos = 163" "window_height = 433" "lcd_auto = 0" "default_stream_info = 0" "start_minimized = 0" "disable_gain_slider = 0" "show_listeners = 1" "listeners_update_rate = 10" "lang_str = system" "vu_low_color = 13762560" "vu_mid_color = -421134336" "vu_high_color = -939524096" "vu_mid_range_start = -12" "vu_high_range_start = -6" "always_show_vu_tabs = 1" "window_title =" "vu_mode = 1" "" "[mp3_codec_stream]" "enc_quality = 3" "stereo_mode = 0" "bitrate_mode = 0" "vbr_quality = 4" "vbr_min_bitrate = 32" "vbr_max_bitrate = 320" "vbr_force_min_bitrate = 0" "resampling_freq = 0" "lowpass_freq_active = 0" "lowpass_freq = 0.000000" "lowpass_width_active = 0" "lowpass_width = 0.000000" "highpass_freq_active = 0" "highpass_freq = 0.000000" "highpass_width_active = 0" "highpass_width = 0.000000" "" "[mp3_codec_rec]" "enc_quality = 3" "stereo_mode = 0" "bitrate_mode = 0" "vbr_quality = 4" "vbr_min_bitrate = 32" "vbr_max_bitrate = 320" "vbr_force_min_bitrate = 0" "resampling_freq = 0" "lowpass_freq_active = 0" "lowpass_freq = 0.000000" "lowpass_width_active = 0" "lowpass_width = 0.000000" "highpass_freq_active = 0" "highpass_freq = 0.000000" "highpass_width_active = 0" "highpass_width = 0.000000" "" "[vorbis_codec_stream]" "bitrate_mode = 0" "vbr_quality = 0" "vbr_min_bitrate = 0" "vbr_max_bitrate = 0" "" "[vorbis_codec_rec]" "bitrate_mode = 0" "vbr_quality = 0" "vbr_min_bitrate = 0" "vbr_max_bitrate = 0" "" "[opus_codec_stream]" "bitrate_mode = 1" "quality = 0" "audio_type = 0" "bandwidth = 0" "" "[opus_codec_rec]" "bitrate_mode = 1" "quality = 0" "audio_type = 0" "bandwidth = 0" "" "[aac_codec_stream]" "bitrate_mode = 0" "afterburner = 0" "profile = 0" "" "[aac_codec_rec]" "bitrate_mode = 0" "afterburner = 0" "profile = 0" "" "[flac_codec_stream]" "bit_depth = 16" "" "[flac_codec_rec]" "bit_depth = 16" "" "[wav_codec_rec]" "bit_depth = 16" "" "[midi]" "dev_name = Disabled" "" "[midi_cmd_0]" "enabled = 0" "channel = 0" "msg_num = 0" "msg_type = 176" "mode = 0" "soft_takeover = 0" "" "[midi_cmd_1]" "enabled = 0" "channel = 0" "msg_num = 1" "msg_type = 176" "mode = 0" "soft_takeover = 0" "" "[midi_cmd_2]" "enabled = 0" "channel = 0" "msg_num = 2" "msg_type = 176" "mode = 0" "soft_takeover = 0" "" "[midi_cmd_3]" "enabled = 0" "channel = 0" "msg_num = 3" "msg_type = 176" "mode = 0" "soft_takeover = 0" "" "[midi_cmd_4]" "enabled = 0" "channel = 0" "msg_num = 4" "msg_type = 176" "mode = 0" "soft_takeover = 0" "" "[midi_cmd_5]" "enabled = 0" "channel = 0" "msg_num = 5" "msg_type = 176" "mode = 0" "soft_takeover = 0" "" "[midi_cmd_6]" "enabled = 0" "channel = 0" "msg_num = 6" "msg_type = 176" "mode = 0" "soft_takeover = 0" "" "[midi_cmd_7]" "enabled = 0" "channel = 0" "msg_num = 7" "msg_type = 176" "mode = 0" "soft_takeover = 0" "" "[midi_cmd_8]" "enabled = 0" "channel = 0" "msg_num = 8" "msg_type = 176" "mode = 0" "soft_takeover = 0" "" "[midi_cmd_9]" "enabled = 0" "channel = 0" "msg_num = 9" "msg_type = 176" "mode = 0" "soft_takeover = 0" "" "[icecast]" "address = localhost" "port = 8000" "password = debian" "type = 1" "tls = 0" "cert_hash =" "mount = stream" "usr = source" "protocol = 0" > /home/debian/butt.txt
# Create VNC directory and set password for the non-root user
USER debian
#RUN mkdir -p /home/debian/.vnc && \
#    echo "debian" | vncpasswd -f > /home/debian/.vnc/passwd && \
#    chmod 600 /home/debian/.vnc/passwd && \
#RUN mkdir -p /home/debian/.vnc/config.d \
# && echo "debian" \
#    | vncpasswd -f -virtual \
#    > /home/debian/.vnc/config.d/Xvnc \
# && chown -R debian:debian /home/debian/.vnc \
# && chmod 600 /home/debian/.vnc/config.d/Xvnc
#RUN sudo apt-get update && sudo apt-get install -y expect \
# && mkdir -p /home/debian/.vnc/config.d \
# && expect <<'EOE'
#    spawn vncpasswd -virtual
#    expect "Password:"
#    send   "debian\r"
#    expect "Verify:"
#    send   "debian\r"
#    expect eof
#EOE
# ensure correct ownership and permissions
#RUN chown -R debian:debian /home/debian/.vnc \
# && chmod -R 600 /home/debian/.vnc/config.d/Xvnc
#
#
# Set up VNC configuration
RUN mkdir -p /home/debian/.vnc && \
    echo "debian" | vncpasswd -f > /home/debian/.vnc/passwd && \
    chmod 600 /home/debian/.vnc/passwd && echo 'if [ -z "$TERM" ] || [ "$TERM" = "unknown" ]; then export TERM="xterm-256color"; fi' >> /home/debian/.bashrc && \
    echo -e "\n#This is a configuration file for butt (broadcast using this tool)\n\n[main]\nbg_color = 252645120\ntxt_color = -256\nserver = icecast\nsrv_ent = icecast\nicy =\nicy_ent =\nnum_of_srv = 1\nnum_of_icy = 0\nsong_update_url_active = 0\nsong_update_url_interval = 1\nsong_update_url =\nsong_path =\nsong_update = 0\nsong_delay = 0\nsong_prefix =\nsong_suffix =\nread_last_line = 0\napp_update_service = 0\napp_update = 0\napp_artist_title_order = 1\ngain = 1.000000\nsignal_threshold = 0.000000\nsilence_threshold = 0.000000\nsignal_detection = 0\nsilence_detection = 0\ncheck_for_update = 1\nstart_agent = 0\nminimize_to_tray = 0\nconnect_at_startup = 1\nforce_reconnecting = 0\nreconnect_delay = 1\nic_charset =\nlog_file =\n\n[audio]\ndevice = 0\ndevice2 = -1\ndev_remember = 1\nsamplerate = 48000\nbitrate = 128\nchannel = 2\nleft_ch = 1\nright_ch = 2\nleft_ch2 = 1\nright_ch2 = 2\ncodec = opus\nresample_mode = 1\nsilence_level = 50.000000\nsignal_level = 50.000000\ndisable_dithering = 0\nbuffer_ms = 50\ndev_name = Default PCM device (default)\ndev2_name = None\n\n[record]\nbitrate = 192\ncodec = opus\nstart_rec = 0\nstop_rec = 0\nrec_after_launch = 0\noverwrite_files = 0\nsync_to_hour  = 0\nsplit_time = 0\nfilename = rec_%Y%m%d-%H%M%S.opus\nsignal_threshold = 0.000000\nsilence_threshold = 0.000000\nsignal_detection = 0\nsilence_detection = 0\nfolder = /home/debian/\n\n[tls]\ncert_file =\ncert_dir =\n\n[dsp]\nequalizer = 0\nequalizer_rec = 0\neq_preset = Manual\ngain1 = 0.000000\ngain2 = 0.000000\ngain3 = 0.000000\ngain4 = 0.000000\ngain5 = 0.000000\ngain6 = 0.000000\ngain7 = 0.000000\ngain8 = 0.000000\ngain9 = 0.000000\ngain10 = 0.000000\ncompressor = 0\ncompressor_rec = 0\naggressive_mode = 0\nthreshold = -20.000000\nratio = 5.000000\nattack = 0.010000\nrelease = 1.000000\nmakeup_gain = 0.000000\n\n[mixer]\nprimary_device_gain = 1.000000\nprimary_device_muted = 0\nsecondary_device_gain = 1.000000\nsecondary_device_muted = 0\nstreaming_gain = 1.000000\nrecording_gain = 1.000000\ncross_fader = 0.000000\n\n[gui]\nattach = 0\nontop = 0\nhide_log_window = 0\nremember_pos = 1\nx_pos = 425\ny_pos = 163\nwindow_height = 433\nlcd_auto = 0\ndefault_stream_info = 0\nstart_minimized = 0\ndisable_gain_slider = 0\nshow_listeners = 1\nlisteners_update_rate = 10\nlang_str = system\nvu_low_color = 13762560\nvu_mid_color = -421134336\nvu_high_color = -939524096\nvu_mid_range_start = -12\nvu_high_range_start = -6\nalways_show_vu_tabs = 1\nwindow_title =\nvu_mode = 1\n\n[mp3_codec_stream]\nenc_quality = 3\nstereo_mode = 0\nbitrate_mode = 0\nvbr_quality = 4\nvbr_min_bitrate = 32\nvbr_max_bitrate = 320\nvbr_force_min_bitrate = 0\nresampling_freq = 0\nlowpass_freq_active = 0\nlowpass_freq = 0.000000\nlowpass_width_active = 0\nlowpass_width = 0.000000\nhighpass_freq_active = 0\nhighpass_freq = 0.000000\nhighpass_width_active = 0\nhighpass_width = 0.000000\n\n[mp3_codec_rec]\nenc_quality = 3\nstereo_mode = 0\nbitrate_mode = 0\nvbr_quality = 4\nvbr_min_bitrate = 32\nvbr_max_bitrate = 320\nvbr_force_min_bitrate = 0\nresampling_freq = 0\nlowpass_freq_active = 0\nlowpass_freq = 0.000000\nlowpass_width_active = 0\nlowpass_width = 0.000000\nhighpass_freq_active = 0\nhighpass_freq = 0.000000\nhighpass_width_active = 0\nhighpass_width = 0.000000\n\n[vorbis_codec_stream]\nbitrate_mode = 0\nvbr_quality = 0\nvbr_min_bitrate = 0\nvbr_max_bitrate = 0\n\n[vorbis_codec_rec]\nbitrate_mode = 0\nvbr_quality = 0\nvbr_min_bitrate = 0\nvbr_max_bitrate = 0\n\n[opus_codec_stream]\nbitrate_mode = 1\nquality = 0\naudio_type = 0\nbandwidth = 0\n\n[opus_codec_rec]\nbitrate_mode = 1\nquality = 0\naudio_type = 0\nbandwidth = 0\n\n[aac_codec_stream]\nbitrate_mode = 0\nafterburner = 0\nprofile = 0\n\n[aac_codec_rec]\nbitrate_mode = 0\nafterburner = 0\nprofile = 0\n\n[flac_codec_stream]\nbit_depth = 16\n\n[flac_codec_rec]\nbit_depth = 16\n\n[wav_codec_rec]\nbit_depth = 16\n\n[midi]\ndev_name = Disabled\n\n[midi_cmd_0]\nenabled = 0\nchannel = 0\nmsg_num = 0\nmsg_type = 176\nmode = 0\nsoft_takeover = 0\n\n[midi_cmd_1]\nenabled = 0\nchannel = 0\nmsg_num = 1\nmsg_type = 176\nmode = 0\nsoft_takeover = 0\n\n[midi_cmd_2]\nenabled = 0\nchannel = 0\nmsg_num = 2\nmsg_type = 176\nmode = 0\nsoft_takeover = 0\n\n[midi_cmd_3]\nenabled = 0\nchannel = 0\nmsg_num = 3\nmsg_type = 176\nmode = 0\nsoft_takeover = 0\n\n[midi_cmd_4]\nenabled = 0\nchannel = 0\nmsg_num = 4\nmsg_type = 176\nmode = 0\nsoft_takeover = 0\n\n[midi_cmd_5]\nenabled = 0\nchannel = 0\nmsg_num = 5\nmsg_type = 176\nmode = 0\nsoft_takeover = 0\n\n[midi_cmd_6]\nenabled = 0\nchannel = 0\nmsg_num = 6\nmsg_type = 176\nmode = 0\nsoft_takeover = 0\n\n[midi_cmd_7]\nenabled = 0\nchannel = 0\nmsg_num = 7\nmsg_type = 176\nmode = 0\nsoft_takeover = 0\n\n[midi_cmd_8]\nenabled = 0\nchannel = 0\nmsg_num = 8\nmsg_type = 176\nmode = 0\nsoft_takeover = 0\n\n[midi_cmd_9]\nenabled = 0\nchannel = 0\nmsg_num = 9\nmsg_type = 176\nmode = 0\nsoft_takeover = 0\n\n[icecast]\naddress = localhost\nport = 8000\npassword = debian\ntype = 1\ntls = 0\ncert_hash =\nmount = stream\nusr = source\nprotocol = 0" > /home/debian/butt.txt && \
    echo -e "#This is a configuration file for butt (broadcast using this tool)\n\n[main]\nbg_color = 252645120\ntxt_color = -256\nserver = web\nsrv_ent = web\nicy = \nicy_ent = \nnum_of_srv = 1\nnum_of_icy = 0\nsong_update_url_active = 0\nsong_update_url_interval = 1\nsong_update_url =\nsong_path = \nsong_update = 0\nsong_delay = 0\nsong_prefix = \nsong_suffix = \nread_last_line = 0\napp_update_service = 0\napp_update = 0\napp_artist_title_order = 1\ngain = 1.000000\nsignal_threshold = 0.000000\nsilence_threshold = 0.000000\nsignal_detection = 0\nsilence_detection = 0\ncheck_for_update = 1\nstart_agent = 0\nminimize_to_tray = 1\nconnect_at_startup = 1\nforce_reconnecting = 1\nreconnect_delay = 5\nic_charset = \nlog_file = \n\n[audio]\ndevice = 0\ndevice2 = -1\ndev_remember = 1\nsamplerate = 48000\nbitrate = 128\nchannel = 2\nleft_ch = 1\nright_ch = 2\nleft_ch2 = 1\nright_ch2 = 2\ncodec = opus\nresample_mode = 1\nsilence_level = 50.000000\nsignal_level = 50.000000\ndisable_dithering = 0\nbuffer_ms = 50\ndev_name = Default PCM device (default)\ndev2_name = None\n\n[record]\nbitrate = 192\ncodec = opus\nstart_rec = 0\nstop_rec = 0\nrec_after_launch = 0\noverwrite_files = 0\nsync_to_hour = 0\nsplit_time = 0\nfilename = rec_%Y%m%d-%H%M%S.opus\nsignal_threshold = 0.000000\nsilence_threshold = 0.000000\nsignal_detection = 0\nsilence_detection = 0\nfolder = /home/debian/\n\n[tls]\ncert_file = \ncert_dir = \n\n[dsp]\nequalizer = 0\nequalizer_rec = 0\neq_preset = Manual\ngain1 = 0.000000\ngain2 = 0.000000\ngain3 = 0.000000\ngain4 = 0.000000\ngain5 = 0.000000\ngain6 = 0.000000\ngain7 = 0.000000\ngain8 = 0.000000\ngain9 = 0.000000\ngain10 = 0.000000\ncompressor = 0\ncompressor_rec = 0\naggressive_mode = 0\nthreshold = -20.000000\nratio = 5.000000\nattack = 0.010000\nrelease = 1.000000\nmakeup_gain = 0.000000\n\n[mixer]\nprimary_device_gain = 1.000000\nprimary_device_muted = 0\nsecondary_device_gain = 1.000000\nsecondary_device_muted = 0\nstreaming_gain = 1.000000\nrecording_gain = 1.000000\ncross_fader = 0.000000\n\n[gui]\nattach = 0\nontop = 0\nhide_log_window = 0\nremember_pos = 1\nx_pos = 745\ny_pos = 343\nwindow_height = 0\nlcd_auto = 0\ndefault_stream_info = 0\nstart_minimized = 0\ndisable_gain_slider = 0\nshow_listeners = 1\nlisteners_update_rate = 10\nlang_str = system\nvu_low_color = 13762560\nvu_mid_color = -421134336\nvu_high_color = -939524096\nvu_mid_range_start = -12\nvu_high_range_start = -6\nalways_show_vu_tabs = 1\nwindow_title = \nvu_mode = 1\n\n[mp3_codec_stream]\nenc_quality = 3\nstereo_mode = 0\nbitrate_mode = 0\nvbr_quality = 4\nvbr_min_bitrate = 32\nvbr_max_bitrate = 320\nvbr_force_min_bitrate = 0\nresampling_freq = 0\nlowpass_freq_active = 0\nlowpass_freq = 0.000000\nlowpass_width_active = 0\nlowpass_width = 0.000000\nhighpass_freq_active = 0\nhighpass_freq = 0.000000\nhighpass_width_active = 0\nhighpass_width = 0.000000\n\n[mp3_codec_rec]\nenc_quality = 3\nstereo_mode = 0\nbitrate_mode = 0\nvbr_quality = 4\nvbr_min_bitrate = 32\nvbr_max_bitrate = 320\nvbr_force_min_bitrate = 0\nresampling_freq = 0\nlowpass_freq_active = 0\nlowpass_freq = 0.000000\nlowpass_width_active = 0\nlowpass_width = 0.000000\nhighpass_freq_active = 0\nhighpass_freq = 0.000000\nhighpass_width_active = 0\nhighpass_width = 0.000000\n\n[vorbis_codec_stream]\nbitrate_mode = 0\nvbr_quality = 0\nvbr_min_bitrate = 0\nvbr_max_bitrate = 0\n\n[vorbis_codec_rec]\nbitrate_mode = 0\nvbr_quality = 0\nvbr_min_bitrate = 0\nvbr_max_bitrate = 0\n\n[opus_codec_stream]\nbitrate_mode = 1\nquality = 0\naudio_type = 0\nbandwidth = 0\n\n[opus_codec_rec]\nbitrate_mode = 1\nquality = 0\naudio_type = 0\nbandwidth = 0\n\n[aac_codec_stream]\nbitrate_mode = 0\nafterburner = 0\nprofile = 0\n\n[aac_codec_rec]\nbitrate_mode = 0\nafterburner = 0\nprofile = 0\n\n[flac_codec_stream]\nbit_depth = 16\n\n[flac_codec_rec]\nbit_depth = 16\n\n[wav_codec_rec]\nbit_depth = 16\n\n[midi]\ndev_name = Disabled\n\n[midi_cmd_0]\nenabled = 0\nchannel = 0\nmsg_num = 0\nmsg_type = 176\nmode = 0\nsoft_takeover = 0\n\n[midi_cmd_1]\nenabled = 0\nchannel = 0\nmsg_num = 1\nmsg_type = 176\nmode = 0\nsoft_takeover = 0\n\n[midi_cmd_2]\nenabled = 0\nchannel = 0\nmsg_num = 2\nmsg_type = 176\nmode = 0\nsoft_takeover = 0\n\n[midi_cmd_3]\nenabled = 0\nchannel = 0\nmsg_num = 3\nmsg_type = 176\nmode = 0\nsoft_takeover = 0\n\n[midi_cmd_4]\nenabled = 0\nchannel = 0\nmsg_num = 4\nmsg_type = 176\nmode = 0\nsoft_takeover = 0\n\n[midi_cmd_5]\nenabled = 0\nchannel = 0\nmsg_num = 5\nmsg_type = 176\nmode = 0\nsoft_takeover = 0\n\n[midi_cmd_6]\nenabled = 0\nchannel = 0\nmsg_num = 6\nmsg_type = 176\nmode = 0\nsoft_takeover = 0\n\n[midi_cmd_7]\nenabled = 0\nchannel = 0\nmsg_num = 7\nmsg_type = 176\nmode = 0\nsoft_takeover = 0\n\n[midi_cmd_8]\nenabled = 0\nchannel = 0\nmsg_num = 8\nmsg_type = 176\nmode = 0\nsoft_takeover = 0\n\n[midi_cmd_9]\nenabled = 0\nchannel = 0\nmsg_num = 9\nmsg_type = 176\nmode = 0\nsoft_takeover = 0\n\n[midi_cmd_10]\nenabled = 0\nchannel = 0\nmsg_num = 10\nmsg_type = 176\nmode = 0\nsoft_takeover = 0\n\n[midi_cmd_11]\nenabled = 0\nchannel = 0\nmsg_num = 11\nmsg_type = 176\nmode = 0\nsoft_takeover = 0\n\n[midi_cmd_12]\nenabled = 0\nchannel = 0\nmsg_num = 12\nmsg_type = 176\nmode = 0\nsoft_takeover = 0\n\n[midi_cmd_13]\nenabled = 0\nchannel = 0\nmsg_num = 13\nmsg_type = 176\nmode = 0\nsoft_takeover = 0\n\n[web]\naddress = (none)\nport = 0\npassword = (none)\ntype = 3\ntls = 0\ncustom_listener_url = \ncustom_listener_mount = \ncert_hash = \nmount = (none)\nusr = (none)\nwebrtc_ice = \nwebrtc_whip = localhost:8889/stream/whip\nwebrtc_auth = \n" > /home/debian/buttweb.txt 
#RUN echo -e "\n#!/bin/sh\nexec >> /home/debian/xstartup.log 2>&1\nset -x\n# Check if .Xresources exists and load it\n[ -r \$HOME/.Xresources ] && xrdb \$HOME/.Xresources\n\n# Set default shell to /bin/bash if not already set\ntest x\"\$SHELL\" = x\"\" && SHELL=/bin/bash\n\n# If no arguments are passed, set default session\ntest x\"\$1\" = x\"\" && set -- default\n#export XAUTHORITY=/dev/null\nxhost +\nsudo -u debian -i bash -x >>/home/debian/xstartup.log 2>&1 <<'EOF'\nexport DISPLAY=:1\nexport G_MESSAGES_DEBUG=all\nexport XAUTHORITY=/home/debian/.Xauthority\n# Start vncconfig in the background\nvncconfig -iconic &\necho -e "gsettings set org.gnome.shell favorite-apps \"['firefox.desktop', 'org.gnome.Evolution.desktop', 'org.gnome.Nautilus.desktop', 'org.kde.discover.desktop', 'xfce4-terminal.desktop', 'org.gnome.TextEditor.desktop', 'org.gnome.Calculator.desktop']\"\ngsettings set org.gnome.desktop.session idle-delay 0\n\ngsettings set org.gnome.desktop.screensaver lock-enabled false\n\ngsettings set org.gnome.desktop.interface color-scheme 'prefer-dark'\nbutt -c /home/debian/butt.txt > /dev/null 2>&1  &\nwhile ! find /usr/local/bin -maxdepth 1 -name 'butt*.AppImage' -print -quit | grep -q .; do sleep 5; done && sleep 5 && rm ~/.local/share/keyrings/login.keyring && find /usr/local/bin -maxdepth 1 -name 'butt*.AppImage' -exec {} -c /home/debian/buttweb.txt \; -quit > /dev/null 2>&1  &\n#/usr/libexec/gnome-initial-setup &\n#/usr/libexec/xfce-polkit &\nexport XDG_SESSION_TYPE=x11\n# Start a login shell and launch the desktop session\nexec gnome-session --debug >> /home/debian/xstartup.log 2>&1\n#dbus-launch --exit-with-session gnome-session\n#exec /etc/X11/Xsession \"\$@\"\nEOF\n\n# Stop the VNC server if needed\nvncserver -kill \$DISPLAY" > ~/.vnc/xstartup && chmod u+x ~/.vnc/xstartup 
RUN cat > ~/.vnc/xstartup <<'END_SCRIPT'
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
# … earlier bits where you export DISPLAY, XAUTHORITY, PULSE_SERVER …

# 1) capture and feed your env into systemd-user
#systemctl --user import-environment DISPLAY XAUTHORITY XDG_SESSION_TYPE

# 2) fire off the GNOME session under systemd, and hand off
#exec systemctl --user start gnome-session@gnome.service --no-block
# inside xstartup, after exporting your env
#systemctl --user import-environment DISPLAY XAUTHORITY 

# call the binary directly under your shell (so you can still capture stdout):
#exec /usr/libexec/gnome-session-binary \
#     --session=gnome \
#     --systemd-service \
#     --debug  >>"$HOME/xstartup-gnome-debug.log" 2>&1


EOF

vncserver -kill $DISPLAY
END_SCRIPT

#chmod u+x ~/.vnc/xstartup
RUN chmod u+x ~/.vnc/xstartup && mkdir -p /home/debian/Downloads /home/debian/.cache /home/debian/.config /home/debian/.local /home/debian/.gnupg /home/debian/Desktop && \
    sudo chmod 700 /home/debian/.gnupg /home/debian/.local && echo -e "\n[Backends]\nEnabledBackends=flatpak-backend\n\n[FlatpakSources]\nSources=flathub\n\n[PackageKit]\nEnabled=false\nInitialUpdate=false\n\n[ResourcesModel]\ncurrentApplicationBackend=flatpak-backend" > /home/debian/.config/discoverrc && sed -i '/-e/d' /home/debian/.config/discoverrc && sed -i '/-e/d' /home/debian/.vnc/xstartup && \
    sudo chmod 755 /home/debian/.config && sudo chmod 777 /home/debian/.cache && sudo chmod u+rw  /home/debian/.cache/ && echo done


#RUN echo -e "\n#!/bin/bash\nsleep 15\nsudo sed -i '/^ExecStartPre=/d' /etc/systemd/system/installer.service\n#sudo sed -i '/^Environment=app=.*xargs.*grep app.*/d' /etc/systemd/system/installer.service\nsudo sed -i '/firstrun.sh/d' /etc/systemd/system/installer.service\nsudo systemctl daemon-reload" > /home/debian/.cache/firstrun.sh && sudo sed -i '/-e/d' /home/debian/.cache/firstrun.sh || true
# Copy the script
#COPY installer.py /home/debian/.cache/
#COPY res.sh /home/debian/.cache/
#COPY *.desktop /home/debian/Desktop/
#COPY blank_login.keyring /home/user/.local/share/keyrings/login.keyring
RUN curl -o /home/debian/.cache/res.sh https://raw.githubusercontent.com/nagamuslim/debian-gnome-headless/main/res.sh && curl -o /home/debian/.cache/installer.py https://raw.githubusercontent.com/nagamuslim/debian-gnome-headless/main/installer.py && curl -o /home/debian/mediamtx.yml https://raw.githubusercontent.com/nagamuslim/debian-gnome-headless/main/mediamtx.yml && \
    sudo chmod +x /home/debian/.cache/installer.py && sudo chmod +x /home/debian/.cache/res.sh  && \
    mkdir -p ~/.config/tigervnc && cp ~/.vnc/* ~/.config/tigervnc/ && sudo chmod 755 /home/debian && sudo cp /home/debian/mediamtx.yml /mediamtx.yml 
#RUN sudo chown -R debian:debian /home/debian/.* && sudo chown -R debian:debian /home/debian
USER root
RUN ln -s /home/debian/Downloads /mnt1 && sed -i '/@include common-auth/a auth       optional   pam_gnome_keyring.so' /etc/pam.d/login && sed -i '/@include common-session/a session    optional   pam_gnome_keyring.so auto_start' /etc/pam.d/login
WORKDIR /mnt1
RUN mkdir /etc/gnome-initial-setup/ && \
    sudo mkdir -p /etc/polkit-1/rules.d && sudo tee /etc/polkit-1/rules.d/49-nopasswd-flatpak.rules > /dev/null << 'EOF'
polkit.addRule(function(action, subject) {
    return polkit.Result.YES;
});
EOF

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
# … earlier image / user setup …
RUN set -eux; \
    \
    # create the .ssh dirs
    mkdir -p /home/debian/.ssh /root/.ssh; \
    \
    # generate both keys (will overwrite if they already exist)
    ssh-keygen -t ed25519 \
      -C "debian-to-ubuntu-key" \
      -f /home/debian/.ssh/id_ed25519 \
      -N ""; \
    ssh-keygen -t ed25519 \
      -C "root-to-ubuntu-key" \
      -f /root/.ssh/id_ed25519 \
      -N ""; \
    \
    # merge both public keys into a single file
    cat /root/.ssh/id_ed25519.pub \
        /home/debian/.ssh/id_ed25519.pub \
      > /mnt1/test.txt; \
    \
    # fix perms for the debian user’s keys
    chown -R debian:debian /home/debian/.ssh; \
    chmod 700 /home/debian/.ssh; \
    chmod 600 /home/debian/.ssh/id_ed25519; \
    chmod 644 /home/debian/.ssh/id_ed25519.pub

RUN echo "app='$(curl -s https://api.github.com/repos/bluenviron/mediamtx/releases/latest | jq -r '.assets[] | select(.name | test("mediamtx_v.*_linux_amd64\\.tar\\.gz$")) | .browser_download_url') https://danielnoethen.de/butt/release/1.45.0/butt-1.45.0-x86_64.AppImage'" | sudo tee /etc/installer.env
#RUN mkdir /mnt1 && chmod 777 /mnt1 && ln -s /mnt1 /home/debian/Downloads
RUN sed -i.bak '/<\/head>/i\ \ \ \ \<script src="novnc-mediamtx-audio.js" defer></script>' /usr/share/novnc/vnc.html && curl -L   'https://raw.githubusercontent.com/nagamuslim/debian-gnome-headless/main/novnc-mediamtx-audio.js'  -o /usr/share/novnc/novnc-mediamtx-audio.js 

RUN echo "load-module module-simple-protocol-tcp listen=127.0.0.1 format=s16le channels=2 rate=48000 record=true playback=true auth-anonymous=1" >> /etc/pulse/system.pa && sed -i '/-e/d' /home/debian/butt.txt || true && \
    echo -e "\n[Unit]\nDescription=Start TightVNC server at startup\nAfter=network.target\n\n[Service]\nType=forking\nUser=debian\nGroup=debian\nWorkingDirectory=/home/debian\nEnvironmentFile=-/run/vnc.env\nEnvironment=EDITOR=nano\nEnvironment=HOME=/home/debian\nEnvironment=USER=debian\nEnvironment=DISPLAY=:1\n\nPIDFile=/home/debian/.vnc/%H:%i.pid\nExecStartPre=+/home/debian/.cache/res.sh\n#ExecStartPre=-/usr/bin/vncserver -kill :%i > /dev/null 2>&1\nExecStart=/usr/bin/vncserver -geometry ${GEOMETRY} -depth 24 -localhost :%i\n\nExecStop=/usr/bin/vncserver -kill :%i\nExecStopPost=/bin/rm -f /home/debian/.vnc/%H:%i.pid\nTimeoutStartSec=infinity\nTimeoutStopSec=infinity\n[Install]\nWantedBy=multi-user.target" > /etc/systemd/system/vncserver@.service && \
    echo -e "[Unit]\nDescription=noVNC WebSocket Proxy Service\nAfter=network.target\n\n[Service]\nType=simple\nUser=debian\nGroup=debian\nWorkingDirectory=/home/debian\nEnvironment=HOME=/home/debian\nEnvironment=USER=debian\nExecStart=/usr/bin/websockify --web /usr/share/novnc 6080 localhost:5901\nRestart=always\nRestartSec=3\nStandardOutput=syslog\nStandardError=syslog\n\n[Install]\nWantedBy=multi-user.target" | sudo tee /etc/systemd/system/websockify.service > /dev/null && \
    echo -e "[Unit]\nDescription=Sound Service\n\n[Service]\n# Note that notify will only work if --daemonize=no\nType=notify\nExecStart=/usr/bin/pulseaudio --daemonize=no --exit-idle-time=-1 --disallow-exit=true --system --log-target=syslog --log-level=4\nNice=-10\nRestart=always\n\n[Install]\nWantedBy=default.target" > /etc/systemd/system/pulseaudio.service && \
    echo -e "\n[Unit]\nDescription=Dynamic Application Installer Service\nAfter=network-online.target \n\n[Service]\nType=simple\nWorkingDirectory=/home/debian/.cache/\nUser=debian\nGroup=debian\nEnvironmentFile=-/etc/installer.env\nEnvironment=app\nExecStart=/home/debian/.cache/installer.py\nExecStartPost=+/bin/rm -rf /etc/installer.env\nExecStartPost=-/usr/local/bin/mediamtx\nRestart=always\nTimeoutStopSec=infinity\nRestartSec=10\n\n[Install]\nWantedBy=multi-user.target" | sudo tee /etc/systemd/system/installer.service > /dev/null && \
    echo -e "\n[Unit]\nDescription=MediaMTX + BUTT Streaming Service\nAfter=network-online.target installer.service\nWants=installer.service network-online.target\n\n[Service]\nType=simple\n#User=debian\n#Group=debian\n\nExecStart=/usr/local/bin/mediamtx \n#ExecStartPost=/bin/sleep 5\n#ExecStart=/usr/bin/flatpak run de.danielnoethen.butt -c /home/debian/buttweb.txt\n\nRestart=on-failure\nRestartSec=2\nTimeoutStopSec=infinity\n\n[Install]\nWantedBy=multi-user.target" > /etc/systemd/system/mediamtx.service
#RUN echo -e "\n[Unit]\nDescription=MediaMTX + BUTT Streaming Service\nAfter=network-online.target installer.service\nWants=installer.service network-online.target\n\n[Service]\nType=simple\nUser=debian\nGroup=debian\n\n#ExecStart=/usr/local/bin/mediamtx \nExecStart=/usr/local/bin/butt-1.45.0-x86_64.AppImage\n#ExecStart=/usr/bin/flatpak run de.danielnoethen.butt\n\nRestart=on-failure\nRestartSec=10\nTimeoutStopSec=infinity\n\n[Install]\nWantedBy=multi-user.target" > /etc/systemd/system/audioweb.service
# Create IBus systemd service file (required for VNC)

RUN tee /etc/systemd/user/ibus-daemon.service > /dev/null << 'EOF'
[Unit]
Description=IBus Input Method Framework
After=graphical-session.target

[Service]
Type=dbus
BusName=org.freedesktop.IBus
ExecStart=/usr/bin/ibus-daemon --xim --panel disable
Restart=on-failure

[Install]
WantedBy=gnome-session.target
EOF

#systemctl --user enable ibus-daemon
RUN sed -i '/-e/d' /etc/systemd/system/vncserver@.service && sudo sed -i 's|\(ExecStart=.*-geometry\) *|\1 ${GEOMETRY} |' /etc/systemd/system/vncserver@.service && \
    systemctl --user enable ibus-daemon && systemctl enable vncserver@1.service && systemctl enable pulseaudio.service && systemctl enable nginx && \
    systemctl enable websockify.service && systemctl enable icecast2 & dpkg --add-architecture i386 && apt update && \
    systemctl enable installer.service && systemctl enable mediamtx.service && sed -i '/-e/d' /etc/systemd/system/installer.service || true && sed -i '/-e/d' /etc/systemd/system/mediamtx.service || true
# Expose VNC and noVNC ports
EXPOSE 22 5901 6080 6901 8000 8080 8888 8889

# Set environment variables
ENV DISPLAY=:1
ENV EDITOR=nano

# Set the entrypoint to the old script
ENTRYPOINT ["/opt/init-wrapper/sbin/entrypoint.sh"]

# Run VNC server and Websockify as the debian user, then initialize systemd
#CMD ["/lib/systemd/systemd"]
CMD ["/sbin/init"]
