#!/bin/bash
# Script to set VNC geometry based on /etc/profile.d/00docker-env.sh
# Aims to adhere to strict formatting/logic constraints.

# --- Attempt to source the res value ---
# 2>/dev/null suppresses "No such file or directory" if 00docker-env.sh is missing.
RES_STRING=$(grep '^export res=' /etc/profile.d/00docker-env.sh 2>/dev/null)

# --- Exit if res line is not found ---
# Uses command grouping { ...; } for multiple commands after && or ||
[ -n "$RES_STRING" ] || { echo "Error: 'export res=' line not found in /etc/profile.d/00docker-env.sh. Exiting." >&2; exit 0; }

# --- Extract and clean the RES_VALUE ---
# Handles cases like res='1920x1080', res="1920x1080", or res=1920x1080 (though uncommon for export)
RES_VALUE_QUOTED=$(echo "$RES_STRING" | cut -d= -f2-)
RES_VALUE=$(echo "$RES_VALUE_QUOTED" | sed "s/^['\"]//;s/['\"]$//") # Remove leading/trailing ' or "

# --- Exit if RES_VALUE is empty after extraction ---
[ -n "$RES_VALUE" ] || { echo "Error: res variable is empty after extraction from /etc/profile.d/00docker-env.sh. Exiting." >&2; exit 1; }
echo "INFO: Found res='$RES_VALUE' from configuration file." >&2

# --- Determine GEOMETRY using case statement ---
GEOMETRY="" # Initialize GEOMETRY
case "$RES_VALUE" in
    *x*) # Direct WxH format e.g., "1920x1080"
        PARSED_W=$(echo "$RES_VALUE" | cut -dx -f1)
        PARSED_H=$(echo "$RES_VALUE" | cut -dx -f2)
        # Validate that PARSED_W and PARSED_H are numbers. grep -Eq returns 0 on match.
        (echo "$PARSED_W" | grep -Eq '^[0-9]+$' && echo "$PARSED_H" | grep -Eq '^[0-9]+$') && GEOMETRY="$RES_VALUE" || \
        { echo "Warning: Invalid WxH format in res='$RES_VALUE'. Exiting." >&2; exit 1; }
        # No 4K capping here, as per your clarification for manually typed resolutions
        ;;
    "720p"|"hd") GEOMETRY="1280x720" ;;
    "1080p"|"fhd") GEOMETRY="1920x1080" ;;
    "1440p"|"qhd") GEOMETRY="2560x1440" ;; # Corrected 1440o, this is max keyword resolution
    "800p") GEOMETRY="1280x800" ;;
    # Phone aspect ratios - awk for precision, printf "%.0f" to round to nearest integer
    "hd+")   TEMP_W=$(awk 'BEGIN {printf "%.0f", 720*19/9}');    GEOMETRY="${TEMP_W}x720" ;;
    "hd+ 1") TEMP_W=$(awk 'BEGIN {printf "%.0f", 720*18/9}');    GEOMETRY="${TEMP_W}x720" ;;
    "hd+ 2") TEMP_W=$(awk 'BEGIN {printf "%.0f", 720*19/9}');    GEOMETRY="${TEMP_W}x720" ;;
    "hd+ 3") TEMP_W=$(awk 'BEGIN {printf "%.0f", 720*19.5/9}');  GEOMETRY="${TEMP_W}x720" ;;
    "fhd+")  TEMP_W=$(awk 'BEGIN {printf "%.0f", 1080*19/9}');   GEOMETRY="${TEMP_W}x1080" ;;
    "fhd+ 1")TEMP_W=$(awk 'BEGIN {printf "%.0f", 1080*18/9}');   GEOMETRY="${TEMP_W}x1080" ;;
    "fhd+ 2")TEMP_W=$(awk 'BEGIN {printf "%.0f", 1080*19/9}');   GEOMETRY="${TEMP_W}x1080" ;;
    "fhd+ 3")TEMP_W=$(awk 'BEGIN {printf "%.0f", 1080*19.5/9}'); GEOMETRY="${TEMP_W}x1080" ;;
    *) # Unknown keyword
        echo "Warning: Unknown resolution keyword '$RES_VALUE'. Exiting." >&2
        exit 0
        ;;
esac
echo "INFO: Determined VNC GEOMETRY='$GEOMETRY'." >&2

# --- Apply GEOMETRY to VNC service file and reload systemd ---
# GEOMETRY will be set if script reaches here due to exit 1 in case arms for errors.
echo "INFO: Attempting to update VNC service configuration..." >&2 && \
sudo sed -i "s|^\(ExecStart=/usr/bin/vncserver\)\(\s\+-geometry\s\+\)[0-9]*x[0-9]*|\1\2${GEOMETRY}|" /etc/systemd/system/vncserver@.service && \
echo "INFO: /etc/systemd/system/vncserver@.service successfully updated with geometry ${GEOMETRY}." >&2 && \
echo "INFO: Reloading systemd daemon..." >&2 && \
sudo sed -i '/^ExecStartPre=/d' /etc/systemd/system/vncserver@.service || true && \
sudo systemctl daemon-reload && sudo systemctl restart vncserver@1.service && \
echo "INFO: Systemd daemon reloaded. Geometry change will apply on next vncserver@ instance start." >&2 || \
{ echo "Error: Failed to apply VNC geometry or reload systemd." >&2; exit 1; }

echo "INFO: Script finished successfully." >&2
exit 0
