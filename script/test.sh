#!/bin/bash
# Override the echo command to send its output to the systemd journal
echo() {
  # Use 'builtin echo' to run the original echo command,
  # then pipe its output to 'logger' with a tag.
  builtin echo "$@" | logger -t test-script
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

# Set session type and language
export XDG_SESSION_TYPE=x11
lang_val=$(sed -nE "s/^\s*#?\s*export[[:space:]]+DEFAULT_LANG=['\"]?([^'\" ]+)['\"]?/\1/p" /etc/profile.d/00docker-env.sh)
[ -n "$lang_val" ] && export LANG="$lang_val"

echo "Starting GNOME session..."
exec gnome-session
