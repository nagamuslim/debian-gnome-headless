# debian-gnome-headless
dockerfile and issue tracker for nagamuslim/debian-gnome-headless

based on minimum2scp image
support for flatpak cli,darkmode,preinstalled firefox
default password is debian

run by typing: docker run --privileged -d -p 2022:22 -p 5901:5901 -p 6901:6901 nagamuslim/debian-gnome-headless

roadmap:

-fix gnome-terminal(priority)
-fix gnome-software flatpak(priority)
-fix lock screen or remove it completely(priority)
-added support for nix
-added support for indonesian language
-added support for audio
-added chrome remote desktop
-switch to x11vnc

