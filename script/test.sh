gsettings set org.gnome.desktop.screensaver lock-enabled false
gnome-extensions enable ding@rastersoft.com
( current_lang=$(localectl status | grep 'System Locale' | cut -d'=' -f2); while sleep 10; do new_lang=$(localectl status | grep 'System Locale' | cut -d'=' -f2); sys_lang=$(cat /etc/default/locale 2>/dev/null | grep LANG= | cut -d'=' -f2 | tr -d '"'); [ "$current_lang" != "$new_lang" ] || [ "$current_lang" != "$sys_lang" ] && echo "export DEFAULT_LANG='$new_lang'" | sudo tee /etc/profile.d/00docker-env.sh > /dev/null && kill $(cat /home/debian/.vnc/$(hostname):1.pid) && exit; current_lang="$new_lang"; done ) &
lang_val=$(grep '^export DEFAULT_LANG=' /etc/profile.d/00docker-env.sh 2>/dev/null | cut -d"'" -f2); [ -n "$lang_val" ] && export LANG="$lang_val"
