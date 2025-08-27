#!/bin/sh
#
# res.sh — parse VNC resolution & password, export to /run/vnc.env
#

# Where to look for your exports
DEFAULT_CONFIG_FILE="/etc/profile.d/00docker-env.sh"
VNC_CONFIG_FILE=${1:-$DEFAULT_CONFIG_FILE}

# Where systemd will pick up the vars
ENV_FILE="/run/vnc.env"

diff -q "/home/debian/.vnc/xstartup" "/home/debian/.config/tigervnc/xstartup" >/dev/null 2>&1 || cp "/home/debian/.vnc/xstartup" "/home/debian/.config/tigervnc/xstartup"
# Helpers
get_value_from_line() {
    # strip VAR= and any quotes & trailing space
    echo "$1" | cut -d= -f2- \
        | sed "s/^['\"]//;s/['\"]$//;s/[[:space:]]*$//"
}

# 1) Defaults
GEOMETRY="1280x720"
VNC_PASS=""

# 2) Try to parse
if [ -f "$VNC_CONFIG_FILE" ]; then
    # Resolution
    if grep -q '^export res=' "$VNC_CONFIG_FILE"; then
        RES_LINE=$(grep '^export res=' "$VNC_CONFIG_FILE")
        RES_VAL=$(get_value_from_line "$RES_LINE")
        case "$RES_VAL" in
            [0-9]*x[0-9]*)
                W=${RES_VAL%x*}; H=${RES_VAL#*x}
                if [ "$W" -eq "$W" ] 2>/dev/null && [ "$H" -eq "$H" ] 2>/dev/null; then
                    GEOMETRY="$RES_VAL"
                fi
                ;;
            720p|hd)  GEOMETRY="1280x720" ;;
            1080p|fhd) GEOMETRY="1920x1080" ;;
            1440p|qhd) GEOMETRY="2560x1440" ;;
            800p)      GEOMETRY="1280x800" ;;
            *) # unknown → leave default
                ;;
        esac
    fi

    # VNC password overrides
    if grep -q '^export VNC_PASSWORD=' "$VNC_CONFIG_FILE"; then
        VNC_PASS=$(grep '^export VNC_PASSWORD=' "$VNC_CONFIG_FILE" \
                   | get_value_from_line)
    elif grep -q '^export USER_PASSWORD=' "$VNC_CONFIG_FILE"; then
        VNC_PASS=$(grep '^export USER_PASSWORD=' "$VNC_CONFIG_FILE" \
                   | get_value_from_line)
    fi
fi

# 3) Write out the env file (always at least has GEOMETRY)
printf 'GEOMETRY=%s\n' "$GEOMETRY" > "$ENV_FILE"

# 4) If we got a password, install it for VNC
if [ -n "$VNC_PASS" ]; then
    VNC_DIR="/home/debian/.vnc"
    mkdir -p "$VNC_DIR"
    echo "$VNC_PASS" | vncpasswd -f > "$VNC_DIR/passwd"
    chmod 600 "$VNC_DIR/passwd"
fi

exit 0
