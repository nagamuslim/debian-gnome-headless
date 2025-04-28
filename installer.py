#!/usr/bin/env python3

import os
import sys
import subprocess
import tempfile
import shutil
import logging
import re
from urllib.parse import urlparse
from pathlib import Path

# --- Configuration ---
LOG_FORMAT = '%(asctime)s - %(levelname)s - %(message)s'
logging.basicConfig(level=logging.INFO, format=LOG_FORMAT, stream=sys.stdout)

# State file location - /tmp is volatile. Consider /var/tmp or ~/ for persistence.
STATE_FILE = Path("/tmp/last_app_env.txt")
# Fallback configuration file to check if 'app' env var is not set
FALLBACK_CONFIG_FILE = "/etc/profile.d/00docker-env.sh" # Example file

# --- Global Flags ---
IS_ROOT = os.geteuid() == 0
logging.info(f"Running as {'ROOT' if IS_ROOT else 'USER'}")

# --- State Variables ---
success_list = []
failure_list = []
any_failure = False

# --- Helper Functions ---
def run_command(command, check=False, shell=False, cwd=None, needs_sudo=False):
    """Runs a command, handling conditional sudo, returns success, stdout, stderr."""
    actual_command = list(command)
    sudo_used = False
    if needs_sudo and not IS_ROOT:
        actual_command.insert(0, 'sudo')
        sudo_used = True
        # logging.info("Prepending sudo as non-root user.") # Logged inside now
    # else: # Implicitly handle other cases: no sudo needed, or already root

    cmd_str = ' '.join(actual_command)
    logging.info(f"Executing: {cmd_str} {'in '+str(cwd) if cwd else ''} {'(sudo)' if sudo_used else ''}")
    stdout, stderr = "", ""
    try:
        result = subprocess.run(
            actual_command,
            capture_output=True,
            text=True,
            check=check,
            shell=shell,
            cwd=cwd,
            # Set environment? May be needed if sudo clears env vars
            # env=os.environ.copy() # Consider implications
        )
        stdout = result.stdout
        stderr = result.stderr
        logging.debug(f"Command stdout:\n{stdout}")
        if stderr:
            logging.info(f"Command stderr:\n{stderr}")
        return True, stdout, stderr
    except FileNotFoundError:
        logging.error(f"ERROR: Command not found: {actual_command[0]}")
        return False, stdout, stderr
    except subprocess.CalledProcessError as e:
        logging.error(f"ERROR: Command failed with return code {e.returncode}: {cmd_str}")
        logging.error(f"Stderr:\n{e.stderr}")
        logging.error(f"Stdout:\n{e.stdout}")
        return False, e.stdout, e.stderr
    except Exception as e:
        logging.error(f"ERROR: An unexpected error occurred running command {cmd_str}: {e}")
        return False, stdout, stderr

def get_app_list_from_fallback(filepath):
    """Attempts to read app list from fallback config file using grep."""
    logging.info(f"Attempting fallback: Reading app list from {filepath}")
    if not Path(filepath).is_file():
         logging.warning(f"Fallback config file not found: {filepath}")
         return None

    # Command needs sudo to read /etc file if run as user
    # We grep for the line and then process the output in Python
    grep_cmd = ['grep', '^export app=', filepath]
    success, stdout, stderr = run_command(grep_cmd, check=False, needs_sudo=True)

    if not success or not stdout:
        logging.error(f"Failed to grep fallback file or no matching line found: {filepath}")
        if stderr:
             logging.error(f"Stderr from grep: {stderr.strip()}")
        return None

    # Process grep output
    app_line = None
    for line in stdout.strip().splitlines():
        if line.startswith("export app="):
            app_line = line
            break # Use the first matching line

    if not app_line:
         logging.error(f"Matching line found by grep, but processing failed? Line: {stdout.strip()}")
         return None

    # Extract value after "export app="
    try:
        # Simple split, assumes format like export app=VALUE or export app="VALUE" or export app='VALUE'
        raw_value = app_line.split('=', 1)[1].strip()
        # Remove potential surrounding quotes
        if len(raw_value) > 1 and (
            (raw_value.startswith("'") and raw_value.endswith("'")) or \
            (raw_value.startswith('"') and raw_value.endswith('"'))
        ):
            return raw_value[1:-1]
        else:
            return raw_value
    except IndexError:
        logging.error(f"Failed to parse value from grep output line: {app_line}")
        return None

# --- (Keep is_apt_package_installed, clean_app_list, read/write_state_file_raw as before) ---
def is_apt_package_installed(package_name):
    """Checks if an APT package is installed using dpkg-query."""
    logging.info(f"Checking if APT package '{package_name}' is installed...")
    try:
        cmd = ['dpkg-query', '-W', '-f=${Status}', package_name]
        success, stdout, stderr = run_command(cmd, check=False, needs_sudo=False)
        if success and "ok installed" in stdout:
             return True
        if stderr and "no packages found matching" not in stderr.lower():
            logging.warning(f"dpkg-query stderr for {package_name}: {stderr.strip()}")
        return False
    except Exception as e:
        logging.warning(f"Could not check package status for {package_name}: {e}")
        return False

def clean_app_list(raw_list_str):
    """Cleans the raw string from the environment variable source AFTER state check."""
    if not raw_list_str: return []
    cleaned_items = []
    potential_items = re.split(r'\s+', raw_list_str.strip())
    for item in potential_items:
        item = item.strip()
        if len(item) > 1 and ((item.startswith("'") and item.endswith("'")) or \
                              (item.startswith('"') and item.endswith('"'))):
            item = item[1:-1]
        if not item or item.startswith('root@') or item.endswith('#') or item.endswith('$'):
             logging.debug(f"Ignoring potential junk item during cleaning: '{item}'")
             continue
        cleaned_items.append(item)
    return cleaned_items

def read_state_file_raw(filepath):
    """Reads the raw content of the state file."""
    if not filepath.exists(): return None
    try:
        with open(filepath, 'r') as f: return f.read().strip()
    except Exception as e:
        logging.warning(f"Could not read state file {filepath}: {e}. Treating as non-existent.")
        return None

def write_state_file_raw(filepath, content):
    """Writes the raw content to the state file."""
    try:
        filepath.parent.mkdir(parents=True, exist_ok=True)
        with open(filepath, 'w') as f: f.write(content)
        logging.info(f"Updated state file: {filepath}")
    except Exception as e:
        logging.error(f"ERROR: Could not write state file {filepath}: {e}")

# --- Main Logic ---
logging.info("Script started.")

# 1. Determine App List Source (Env Var or Fallback)
app_list_str_raw = os.getenv('app')
source_description = "environment variable 'app'"

if not app_list_str_raw:
    logging.info("Environment variable 'app' is empty or not set. Attempting fallback.")
    app_list_str_raw = get_app_list_from_fallback(FALLBACK_CONFIG_FILE)
    if app_list_str_raw is None:
         app_list_str_raw = "" # Ensure it's an empty string if fallback fails
         source_description = f"fallback file {FALLBACK_CONFIG_FILE} (failed or empty)"
    else:
         source_description = f"fallback file {FALLBACK_CONFIG_FILE}"
         logging.info(f"Using app list from fallback source.")
else:
     logging.info(f"Using app list from environment variable 'app'.")

current_app_raw_stripped = app_list_str_raw.strip()

# 2. Compare with Last Run's Raw State for fast exit
logging.info(f"Reading previous state from {STATE_FILE}")
previous_app_raw = read_state_file_raw(STATE_FILE)

# Handle cases for exit/update
if not current_app_raw_stripped:
    # Current effective list is empty (from either source)
    logging.info(f"No applications specified via {source_description}.")
    if previous_app_raw is not None and previous_app_raw != "":
        logging.info("Removing state file as current desired state is empty.")
        try: STATE_FILE.unlink()
        except OSError as e: logging.warning(f"Could not remove state file {STATE_FILE}: {e}")
    else:
        logging.info("State file already reflects empty environment (or doesn't exist).")
    logging.info("Exiting cleanly (no apps specified).")
    sys.exit(0)

elif current_app_raw_stripped == previous_app_raw:
    # Current matches previous non-empty state
    logging.info(f"App list from {source_description} unchanged since last run. Exiting cleanly.")
    sys.exit(0)

else:
    # State has changed (or file didn't exist), update state file *before* processing
    logging.info(f"App list from {source_description} has changed. Updating state file and proceeding.")
    write_state_file_raw(STATE_FILE, current_app_raw_stripped)
    # Proceed to cleaning and installation

# 3. Clean the App List (only if we didn't exit early)
logging.info(f"Raw app list content being processed: \"{current_app_raw_stripped}\"")
current_app_items = clean_app_list(current_app_raw_stripped)
logging.info(f"Cleaned application list for processing: {current_app_items}")

if not current_app_items:
     logging.warning("No valid application items found after cleaning, although raw source was not empty. Check source content. Exiting.")
     sys.exit(0) # Exit cleanly, nothing to install


# 4. Use a temporary directory for all downloads/extractions in this run
with tempfile.TemporaryDirectory(prefix="app_install_") as temp_run_dir:
    logging.info(f"Using temporary directory: {temp_run_dir}")
    temp_run_path = Path(temp_run_dir)

    # 5. Parse the List and Process Each Item
    for item in current_app_items:
        logging.info(f"--- Processing item: {item} ---") # Marker for clarity
        item_type = "unknown"
        install_success = False # Reset for each item

        # 6. Detect Software Type (Checks are case-insensitive for suffixes)
        is_url = item.startswith(('http://', 'https://'))
        item_lower = item.lower()
        is_deb = item_lower.endswith('.deb')
        # More robust check for .deb in URL path segment, ignoring query params
        parsed_url_path = urlparse(item).path if is_url else ""
        is_deb_url_with_query = is_url and '.deb' in parsed_url_path.split('/')[-1]

        is_tar_gz = item_lower.endswith('.tar.gz')
        is_bin = item_lower.endswith('.bin')
        is_appimage = item_lower.endswith('.appimage')

        is_flatpak_id = item.count('.') >= 2 and \
                        not is_url and not is_deb and not is_tar_gz and \
                        not is_bin and not is_appimage

        # Determine Type
        if is_url and (is_deb or is_deb_url_with_query): item_type = "deb_url"
        elif is_url and (is_tar_gz or is_bin or is_appimage): item_type = "archive_or_bin_url"
        elif is_flatpak_id: item_type = "flatpak"
        elif not is_url and not any(item_lower.endswith(s) for s in ['.deb','.tar.gz','.bin','.appimage']) and '/' not in item:
             if is_apt_package_installed(item):
                  logging.info(f"APT package '{item}' is already installed.")
                  success_list.append(f"{item} (already installed)")
                  continue
             else: item_type = "apt"
        else:
             logging.warning(f"Could not determine known type for item: {item}")
             item_type = "unknown"

        logging.info(f"Detected type: {item_type}")

        # 7. Install the Software
        if item_type == "apt":
            logging.info(f"Attempting to install APT package: {item}")
            success, _, _ = run_command(['apt', 'install', '-y', item], needs_sudo=True)
            if success: install_success = True
            else: logging.error(f"ERROR: Failed to install APT package: {item}")

        elif item_type == "deb_url":
            logging.info(f"Attempting to install .deb from URL: {item}")
            wget_cmd = ['wget', '--content-disposition', '--timeout=60', '--tries=3', '-P', str(temp_run_path), item]
            download_success, _, stderr = run_command(wget_cmd, needs_sudo=False)
            deb_tmp_path = None
            # (Error handling and file finding logic remains same as previous version)
            if download_success:
                 downloaded_files = list(temp_run_path.glob('*.deb'))
                 if not downloaded_files:
                     if "unable to deduce filename" in stderr.lower(): logging.error(f"ERROR: wget could not determine filename for URL {item}")
                     else: logging.error(f"ERROR: Download OK but no .deb file found for URL {item}")
                 elif len(downloaded_files) > 1:
                     logging.warning(f"Multiple .deb files found. Using first: {downloaded_files[0].name}")
                     deb_tmp_path = downloaded_files[0]
                 else:
                     deb_tmp_path = downloaded_files[0]
                     logging.info(f"Downloaded: {deb_tmp_path.name}")
            else: logging.error(f"ERROR: Failed to download .deb from URL: {item}")

            if deb_tmp_path:
                logging.info(f"Attempting installation of {deb_tmp_path.name}...")
                apt_install_cmd = ['apt', 'install', '-y', str(deb_tmp_path)]
                install_cmd_success, _, _ = run_command(apt_install_cmd, needs_sudo=True)
                if install_cmd_success: install_success = True
                else: logging.error(f"ERROR: Failed to install .deb file: {deb_tmp_path.name}")


        elif item_type == "flatpak":
            # Simplified: Run flatpak install, rely on sudo handling in run_command
            logging.info(f"Attempting Flatpak install: {item}")
            flatpak_cmd = ['flatpak', 'install', '-y', '--noninteractive', 'flathub', item]
            # needs_sudo=True ensures 'sudo flatpak...' for user, 'flatpak...' for root
            success, _, stderr = run_command(flatpak_cmd, needs_sudo=True)
            if success:
                install_success = True
            else:
                logging.error(f"ERROR: Failed Flatpak install command for {item}.")
                # Log stderr for debugging, might indicate repo issues etc.
                if stderr: logging.error(f"Flatpak stderr: {stderr.strip()}")


        elif item_type == "archive_or_bin_url":
            logging.info(f"Attempting to install archive/binary from URL: {item}")
            wget_cmd = ['wget', '--content-disposition', '--timeout=60', '--tries=3', '-P', str(temp_run_path), item]
            download_success, _, stderr = run_command(wget_cmd, needs_sudo=False)
            downloaded_file_path = None
            # (Error handling and file finding logic remains same)
            if download_success:
                possible_files = [f for f in temp_run_path.iterdir() if f.is_file() and not f.name.startswith('wget-log')]
                if not possible_files:
                    if "unable to deduce filename" in stderr.lower(): logging.error(f"ERROR: wget could not determine filename for URL {item}")
                    else: logging.error(f"ERROR: Download OK but no file found for URL {item}")
                elif len(possible_files) > 1:
                    logging.warning(f"Multiple files found: {[f.name for f in possible_files]}. Trying to select.")
                    priority = ['.tar.gz', '.appimage', '.bin']; found=False
                    for suffix in priority:
                        for f in possible_files:
                            if f.name.lower().endswith(suffix): downloaded_file_path = f; found = True; break
                        if found: break
                    if not found: downloaded_file_path = possible_files[0]; logging.warning(f"Could not reliably select, using first: {downloaded_file_path.name}")
                    else: logging.info(f"Selected downloaded file: {downloaded_file_path.name}")
                else: downloaded_file_path = possible_files[0]; logging.info(f"Downloaded: {downloaded_file_path.name}")
            else: logging.error(f"ERROR: Failed to download archive/binary from URL: {item}")

            # --- Process the downloaded file (remains largely the same) ---
            if downloaded_file_path:
                install_target_dir = Path("/usr/local/bin")
                executable_path_to_move = None; target_name = downloaded_file_path.name
                file_lower = downloaded_file_path.name.lower()

                if file_lower.endswith('.tar.gz'):
                    extract_dir = temp_run_path / f"extract_{downloaded_file_path.stem.replace('.tar', '')}"
                    extract_dir.mkdir(parents=True, exist_ok=True)
                    logging.info(f"Extracting '{downloaded_file_path.name}' to {extract_dir}...")
                    tar_cmd = ['tar', '-xzf', str(downloaded_file_path), '-C', str(extract_dir)]
                    extract_success, _, _ = run_command(tar_cmd, needs_sudo=False)
                    if extract_success:
                        logging.info("Extraction successful. Searching for executable...")
                        # (Executable finding logic remains same)
                        executable_candidates = [e for e in extract_dir.rglob('*') if e.is_file() and os.access(e, os.X_OK)]
                        found_executable = None
                        if not executable_candidates: logging.error(f"ERROR: No executable files found in extracted archive for {item}")
                        elif len(executable_candidates) == 1: found_executable = executable_candidates[0]; logging.info(f"Found unique executable: {found_executable.name}")
                        else:
                             logging.warning(f"Multiple executables found: {[e.name for e in executable_candidates]}. Trying best match.")
                             archive_stem = downloaded_file_path.stem.replace('.tar', ''); best_match = None
                             for c in executable_candidates:
                                 if c.name == archive_stem: best_match = c; break
                             if best_match: found_executable = best_match; logging.info(f"Selected executable matching archive name: {found_executable.name}")
                             else: found_executable = executable_candidates[0]; logging.warning(f"Could not determine best match, using first found: {found_executable.name}")
                        if found_executable: executable_path_to_move = found_executable; target_name = found_executable.name
                    else: logging.error(f"ERROR: Failed to extract archive: {downloaded_file_path.name}")

                elif file_lower.endswith(('.bin', '.appimage')):
                    logging.info(f"Handling standalone executable: {downloaded_file_path.name}")
                    try:
                        downloaded_file_path.chmod(downloaded_file_path.stat().st_mode | 0o111) # Add execute bits
                        executable_path_to_move = downloaded_file_path
                        logging.info(f"Set execute permission on {downloaded_file_path.name}")
                    except Exception as e: logging.error(f"ERROR: Failed to set execute permission on {downloaded_file_path}: {e}")
                else: logging.error(f"ERROR: Don't know how to handle downloaded file type: {downloaded_file_path.name}")

                # Move the executable (remains same)
                if executable_path_to_move:
                    target_path = install_target_dir / target_name
                    logging.info(f"Attempting to move '{executable_path_to_move.name}' to '{target_path}'")
                    mv_cmd = ['mv', str(executable_path_to_move), str(target_path)]
                    move_success, _, _ = run_command(mv_cmd, needs_sudo=True)
                    if move_success: install_success = True
                    else: logging.error(f"ERROR: Failed to move executable to {target_path}. Check permissions?")


        elif item_type == "unknown":
            # Error already logged during detection
            failure_list.append(f"{item} (unknown type)")
            any_failure = True

        # 8. Update Result Lists (logic remains same)
        if install_success and not any(f"{item} (already installed)" in s for s in success_list):
             success_list.append(f"{item} ({item_type})")
        elif not install_success and item_type != "unknown" and not any(f"{item} (already installed)" in s for s in success_list):
             failure_list.append(f"{item} ({item_type})")
             any_failure = True # Mark that at least one failure occurred during processing
        logging.info(f"--- Finished processing item: {item} ---\n")


# --- End of processing loop ---

# Temporary directory is automatically cleaned up here

# 9. Report Results (remains same)
logging.info("----- Installation Summary -----")
if success_list:
    logging.info("Successfully installed/handled:")
    for success in success_list: logging.info(f"  - {success}")
else: logging.info("No items were successfully installed/handled in this run.")
if failure_list:
    logging.info("Failed items:")
    for failure in failure_list: logging.info(f"  - {failure}")
else:
     if not success_list and current_app_items : logging.info("No failures detected (items might have been already installed).")
     elif not current_app_items: pass
     else: logging.info("No failures detected in this run.")
logging.info("--------------------------------")

# 10. Set Exit Status (remains same)
if any_failure:
    logging.error("Script finished with failures.")
    sys.exit(1)
else:
    logging.info("Script finished successfully.")
    sys.exit(0)
