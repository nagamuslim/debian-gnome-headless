#!/bin/bash
# Override the echo command to send its output to the systemd journal
echo() {
  # Use 'builtin echo' to run the original echo command,
  # then pipe its output to 'systemd-cat' which correctly associates it with the parent service.
  builtin echo "$@" | systemd-cat -t test.sh
}
# /home/debian/script/test.sh
# Direct logging with set -x
#exec >> /home/debian/test.log 2>&1
#set -x

echo "=== Test script started at $(date) ==="

export DISPLAY=:1
export XAUTHORITY=/home/debian/.Xauthority

detect_butt() {
    echo "Waiting for butt AppImage..."
    # Wait until AppImage appears (system is fully initialized)
    while ! find /usr/local/bin -maxdepth 1 -name 'butt*.AppImage' -print -quit | grep -q .; do
        sleep 5
        echo "Still waiting for butt AppImage..."
    done
    echo "Butt AppImage detected"
}

detect_gnome() {
    local timeout=0
    local max_wait=30 # Total wait time is max_wait * sleep_interval (30 * 2s = 60s)

    echo "Waiting for GNOME Shell and Settings Daemon..."

    # Loop until both processes are found or the timeout is reached
    while ! (pgrep -x gnome-shell >/dev/null && pgrep -x gsd-color >/dev/null); do
        if [ $timeout -ge $max_wait ]; then
            echo "Error: Timed out waiting for GNOME services to start." >&2
            return 1
        fi
        sleep 2
        timeout=$((timeout + 1))
        echo "Waiting for GNOME services... ($timeout/$max_wait)"
    done

    echo "GNOME services are running. Checking color scheme..."

    # Check the current color scheme and set it to dark if it isn't already
    if [[ "$(gsettings get org.gnome.desktop.interface color-scheme)" != *'prefer-dark'* ]]; then
        echo "Setting color scheme to 'prefer-dark'."
        gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark'
    else
        echo "Dark mode is already enabled."
    fi

    return 0
}

# Background task 1: vncconfig
( 
    detect_butt && detect_gnome && 
    echo "Background task 1 started successfully at $(date)" &&
    vncconfig -iconic &
) &
[ "$(cat /tmp/gatekeep.count 2>/dev/null || echo 0)" -gt 1 ] && export GTK_THEME='Adwaita:dark' GTK2_RC_FILES=/usr/share/themes/Adwaita-dark/gtk-2.0/gtkrc
QT_QPA_PLATFORMTHEME=gnome
export QT_QPA_PLATFORMTHEME=gnome
[ -f /etc/profile.d/00docker-env.sh ] && { grep -q "gnome-initial-setup=[\"']?yes[\"']?$" /etc/profile.d/00docker-env.sh 2>/dev/null || { ! grep -q "DEFAULT_LANG" /etc/profile.d/00docker-env.sh 2>/dev/null && ! grep -q "gnome-initial-setup=" /etc/profile.d/00docker-env.sh 2>/dev/null; }; } || echo "3" > /tmp/gatekeep.count
# Configure GNOME settings
pactl list short modules | grep -q module-x11-publish || pactl load-module module-x11-publish display=:1 || true
pactl list short modules | grep -q module-x11-cork-request || pactl load-module module-x11-cork-request display=:1 || true
echo "Configuring GNOME settings..."
gsettings set org.gnome.shell favorite-apps "['firefox.desktop', 'org.gnome.Evolution.desktop', 'org.gnome.Nautilus.desktop', 'org.kde.discover.desktop', 'xfce4-terminal.desktop', 'org.gnome.TextEditor.desktop', 'org.gnome.Calculator.desktop']"
gsettings set org.gnome.desktop.session idle-delay 0
gsettings set org.gnome.desktop.screensaver lock-enabled false
gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark'
gsettings get org.gnome.desktop.interface color-scheme | grep -q 'prefer-dark' || gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark'
gsettings set org.gnome.desktop.background show-desktop-icons true
gnome-extensions enable ding@rastersoft.com

# Background task 2: butt application
( 
    detect_butt && detect_gnome && 
    echo "Background task 2 started successfully at $(date)" &&
    butt -c /home/debian/butt.txt >/dev/null 2>&1 &
) &

# Background task 3: keyring cleanup
( 
    while true; do 
        if [ -f "$HOME/.local/share/keyrings/default" ] || [ -f "$HOME/.local/share/keyrings/Default_keyring.keyring" ]; then 
            break
        fi
        for f in "$HOME"/.local/share/keyrings/*login*.keyring; do 
            [ -f "$f" ] && rm "$f"
        done
        sleep 10
    done
) & 

# Background task 4: desktop shortcuts
( 
    mkdir -p "$HOME/Desktop"
    for f in firefox.desktop org.gnome.Console.desktop xfce4-terminal.desktop org.kde.discover.desktop com.github.tchx84.Flatseal.desktop org.gnome.seahorse.Application.desktop org.gnome.tweaks.desktop com.mattjakeman.ExtensionManager.desktop; do 
        dest="$HOME/Desktop/$f"
        src="/usr/share/applications/$f"
        [ ! -f "$dest" ] && [ -f "$src" ] && cp "$src" "$dest"
    done
    chmod +x "$HOME/Desktop"/*.desktop 2>/dev/null
) &

# Background task 5: butt AppImage
( 
    detect_butt && detect_gnome && 
    sleep 10 && 
    echo "Background task 5 started successfully at $(date)" &&
    /usr/local/bin/butt*.AppImage -c /home/debian/buttweb.txt &
) &

( 
    detect_butt && detect_gnome && 
    sleep 10 && 
    echo "Injected command started successfully at $(date)" &&
    #grep "^export command=" /etc/profile.d/00docker-env.sh | sed "s/export command=//; s/^'//; s/'$//g" | bash
    ( . /etc/profile.d/00docker-env.sh && eval "$command" || true )
) &

# Background task 6: gnome-initial-setup (with gatekeeper)
( 
    C=$(cat /tmp/gatekeep.count 2>/dev/null || echo 0)
    if (( C < 2 )); then
        echo $((C+1)) > /tmp/gatekeep.count
        detect_butt && 
        sleep 10 && 
        sudo rm -rf /home/debian/.config/gnome-initial-setup-done && 
        sleep 5 && 
        ( 
            while true; do 
                pgrep -fx gnome-initial-setup >/dev/null || /usr/libexec/gnome-initial-setup && break
                sleep 5
            done
        ) &
    fi
) &

# Background task 7: language monitoring
( 
    current_lang=$(localectl status | awk -F'LANG=' '/System Locale/ {print $2}')
    while sleep 10; do 
        new_lang=$(localectl status | awk -F'LANG=' '/System Locale/ {print $2}')
        sys_lang=$(cat /etc/default/locale 2>/dev/null | grep LANG= | cut -d'=' -f2 | tr -d '"')
        if [ "$current_lang" != "$new_lang" ] || [ "$current_lang" != "$sys_lang" ]; then
            # Update DEFAULT_LANG without overwriting other variables
            # Check for both commented and uncommented lines
            if grep -q "^#\?export DEFAULT_LANG=" /etc/profile.d/00docker-env.sh 2>/dev/null; then
                # Replace existing DEFAULT_LANG line (commented or not)
                sudo sed -i "s|^#\?export DEFAULT_LANG=.*|export DEFAULT_LANG='$new_lang'|" /etc/profile.d/00docker-env.sh
            else
                # Append if doesn't exist
                echo "export DEFAULT_LANG='$new_lang'" | sudo tee -a /etc/profile.d/00docker-env.sh > /dev/null
            fi
            gnome-session-quit --logout --no-prompt
            exit
        fi
        current_lang="$new_lang"
    done
) &

# Background task: Dynamic second monitor with x11vnc/websockify
(
    detect_gnome || exit 1
    
    SECOND_MONITOR_ACTIVE=false
    X11VNC_PID=""
    WEBSOCKIFY_PID=""
    CHECK_INTERVAL=10
    
    # Function to get resolution from res.sh or default to 720p
    get_resolution() {
        local width height
        
        # Try to read from /run/vnc.env (set by res.sh)
        if [ -f /run/vnc.env ]; then
            local geom=$(grep "^GEOMETRY=" /run/vnc.env | cut -d'=' -f2)
            if [ -n "$geom" ]; then
                width=$(echo "$geom" | cut -d'x' -f1)
                height=$(echo "$geom" | cut -d'x' -f2)
                echo "${width}x${height}"
                return
            fi
        fi
        
        # Try to parse from /etc/profile.d/00docker-env.sh
        if [ -f /etc/profile.d/00docker-env.sh ]; then
            local res_val=$(grep "^export res=" /etc/profile.d/00docker-env.sh | cut -d'=' -f2 | tr -d '"' | tr -d "'")
            if [ -n "$res_val" ]; then
                case "$res_val" in
                    [0-9]*x[0-9]*)
                        echo "$res_val"
                        return
                        ;;
                    720p|hd)
                        echo "1280x720"
                        return
                        ;;
                    1080p|fhd)
                        echo "1920x1080"
                        return
                        ;;
                    1440p|qhd)
                        echo "2560x1440"
                        return
                        ;;
                    800p)
                        echo "1280x800"
                        return
                        ;;
                esac
            fi
        fi
        
        # Default to 720p
        echo "1280x720"
    }
    
    echo "Starting dynamic second monitor service..."
    
    # Function to check if there are waiting/active connections
    check_for_connections() {
        # Check for TCP connections on ports we want to serve
        # Port 5903: x11vnc for second monitor
        # Port 6903: websockify for second monitor web access
        
        # Check if any client is connected or listening for these ports
        local x11vnc_conn=$(ss -tn state established "( sport = :5902 )" 2>/dev/null | grep -c ESTAB)
        local websock_conn=$(ss -tn state established "( sport = :6902 )" 2>/dev/null | grep -c ESTAB)
        
        # Also check for incoming connections (SYN-RECV state)
        local x11vnc_waiting=$(ss -tn state syn-recv "( sport = :5902 )" 2>/dev/null | grep -c SYN-RECV)
        local websock_waiting=$(ss -tn state syn-recv "( sport = :6902 )" 2>/dev/null | grep -c SYN-RECV)
        
        local total=$((x11vnc_conn + websock_conn + x11vnc_waiting + websock_waiting))
        
        echo "$total"
    }
    
    # Function to create second monitor and start services
    start_second_monitor() {
        echo "[$(date)] Creating second monitor VNC-1..."
        
        # Get resolution from res.sh
        local resolution=$(get_resolution)
        local width=$(echo "$resolution" | cut -d'x' -f1)
        local height=$(echo "$resolution" | cut -d'x' -f2)
        local total_width=$((width * 2))
        
        echo "[$(date)] Using resolution: ${resolution} (total framebuffer: ${total_width}x${height})"
        
        # Check if VNC-1 already exists
        if ! xrandr --listmonitors | grep -q "VNC-1"; then
            # Expand framebuffer first
            if xrandr --fb ${total_width}x${height} 2>/dev/null; then
                echo "[$(date)] Framebuffer expanded to ${total_width}x${height}"
                sleep 1
            else
                echo "[$(date)] Warning: Could not expand framebuffer"
            fi
            
            # Create second monitor positioned to the right of first
            if xrandr --setmonitor VNC-1 ${width}x${height}+${width}+0 none 2>/dev/null; then
                echo "[$(date)] VNC-1 monitor created at ${width}x${height}+${width}+0"
                sleep 2
            else
                echo "[$(date)] Failed to create VNC-1 monitor"
                return 1
            fi
        else
            echo "[$(date)] VNC-1 already exists"
        fi
        
        # Start x11vnc for second monitor if not running
        if [ -z "$X11VNC_PID" ] || ! kill -0 "$X11VNC_PID" 2>/dev/null; then
            echo "[$(date)] Starting x11vnc for VNC-1 (${width}x${height}+${width}+0)..."
            x11vnc -display :1 \
                   -clip ${width}x${height}+${width}+0 \
                   -rfbport 5902 \
                   -forever \
                   -shared \
                   -nopw \
                   -bg \
                   -o /tmp/x11vnc-vnc1.log \
                   -pid /tmp/x11vnc-vnc1.pid
            
            # Get PID
            sleep 1
            if [ -f /tmp/x11vnc-vnc1.pid ]; then
                X11VNC_PID=$(cat /tmp/x11vnc-vnc1.pid)
                echo "[$(date)] x11vnc started with PID: $X11VNC_PID"
            fi
        fi
        
        # Start websockify for web access if not running
        if [ -z "$WEBSOCKIFY_PID" ] || ! kill -0 "$WEBSOCKIFY_PID" 2>/dev/null; then
            echo "[$(date)] Starting websockify for VNC-1..."
            websockify --web /usr/share/novnc 6902 localhost:5902 \
                       > /tmp/websockify-vnc1.log 2>&1 &
            WEBSOCKIFY_PID=$!
            echo "[$(date)] websockify started with PID: $WEBSOCKIFY_PID"
        fi
        
        SECOND_MONITOR_ACTIVE=true
    }
    
    # Function to stop services and destroy second monitor
    stop_second_monitor() {
        echo "[$(date)] Stopping second monitor services..."
        
        # Stop x11vnc
        if [ -n "$X11VNC_PID" ] && kill -0 "$X11VNC_PID" 2>/dev/null; then
            echo "[$(date)] Stopping x11vnc (PID: $X11VNC_PID)..."
            kill "$X11VNC_PID" 2>/dev/null || true
            sleep 1
            kill -9 "$X11VNC_PID" 2>/dev/null || true
            X11VNC_PID=""
        fi
        
        # Stop websockify
        if [ -n "$WEBSOCKIFY_PID" ] && kill -0 "$WEBSOCKIFY_PID" 2>/dev/null; then
            echo "[$(date)] Stopping websockify (PID: $WEBSOCKIFY_PID)..."
            kill "$WEBSOCKIFY_PID" 2>/dev/null || true
            sleep 1
            kill -9 "$WEBSOCKIFY_PID" 2>/dev/null || true
            WEBSOCKIFY_PID=""
        fi
        
        # Get original resolution for shrinking framebuffer
        local resolution=$(get_resolution)
        
        # Remove second monitor
        if xrandr --listmonitors | grep -q "VNC-1"; then
            echo "[$(date)] Removing VNC-1 monitor..."
            xrandr --delmonitor VNC-1 2>/dev/null || true
            
            # Shrink framebuffer back to single monitor
            sleep 1
            xrandr --fb $resolution 2>/dev/null || true
            echo "[$(date)] VNC-1 monitor removed, framebuffer reset to $resolution"
        fi
        
        # Cleanup PID files
        rm -f /tmp/x11vnc-vnc1.pid /tmp/x11vnc-vnc1.log /tmp/websockify-vnc1.log
        
        SECOND_MONITOR_ACTIVE=false
    }
    
    # Main monitoring loop
    echo "[$(date)] Dynamic monitor service started. Checking every ${CHECK_INTERVAL}s..."
    echo "[$(date)] Default resolution: $(get_resolution)"
    
    while true; do
        CONNECTION_COUNT=$(check_for_connections)
        
        if [ "$CONNECTION_COUNT" -gt 0 ]; then
            # Users are connected or waiting
            if [ "$SECOND_MONITOR_ACTIVE" = false ]; then
                echo "[$(date)] Detected $CONNECTION_COUNT connection(s). Activating second monitor..."
                start_second_monitor
            else
                echo "[$(date)] Second monitor active. $CONNECTION_COUNT connection(s) present."
            fi
        else
            # No users connected
            if [ "$SECOND_MONITOR_ACTIVE" = true ]; then
                echo "[$(date)] No connections detected. Deactivating second monitor..."
                stop_second_monitor
            fi
        fi
        
        sleep "$CHECK_INTERVAL"
    done
) &

# Set session type and language
export XDG_SESSION_TYPE=x11
lang_val=$(sed -nE "s/^\s*#?\s*export[[:space:]]+DEFAULT_LANG=['\"]?([^'\" ]+)['\"]?/\1/p" /etc/profile.d/00docker-env.sh)
[ -n "$lang_val" ] && export LANG="$lang_val"

echo "Starting GNOME session..."
exec gnome-session
