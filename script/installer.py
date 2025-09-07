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
import time # For potential delay/retry logic if needed

# --- Configuration ---
LOG_FORMAT = '%(asctime)s - %(levelname)s - %(message)s'
logging.basicConfig(level=logging.INFO, format=LOG_FORMAT, stream=sys.stdout)

STATE_FILE = Path("/tmp/last_app_env.txt")
FALLBACK_CONFIG_FILE = "/etc/profile.d/00docker-env.sh" # Example file

# --- Global Flags ---
IS_ROOT = os.geteuid() == 0
logging.info(f"Running as {'ROOT' if IS_ROOT else 'USER'}")

# --- State Variables ---
success_list = []
failure_list = []
any_failure = False # Tracks if any processing step failed

# --- Helper Functions ---
# run_command (remains the same as previous version)
def run_command(command, check=False, shell=False, cwd=None, needs_sudo=False):
    """Runs a command, handling conditional sudo, returns success, stdout, stderr."""
    actual_command = list(command)
    sudo_used = False
    if needs_sudo and not IS_ROOT:
        actual_command.insert(0, 'sudo')
        sudo_used = True
    cmd_str = ' '.join(actual_command)
    logging.info(f"Executing: {cmd_str} {'in '+str(cwd) if cwd else ''} {'(sudo)' if sudo_used else ''}")
    stdout, stderr = "", ""
    try:
        result = subprocess.run(
            actual_command, capture_output=True, text=True, check=check,
            shell=shell, cwd=cwd,
        )
        stdout = result.stdout; stderr = result.stderr
        logging.debug(f"Command stdout:\n{stdout}")
        if stderr: logging.info(f"Command stderr:\n{stderr}")
        return True, stdout, stderr
    except FileNotFoundError:
        logging.error(f"ERROR: Command not found: {actual_command[0]}")
        return False, stdout, stderr
    except subprocess.CalledProcessError as e:
        logging.error(f"ERROR: Command failed (rc={e.returncode}): {cmd_str}")
        logging.error(f"Stderr:\n{e.stderr}"); logging.error(f"Stdout:\n{e.stdout}")
        return False, e.stdout, e.stderr
    except Exception as e:
        logging.error(f"ERROR: Unexpected error running command {cmd_str}: {e}")
        return False, stdout, stderr

# get_app_list_from_fallback (remains the same)
def get_app_list_from_fallback(filepath):
    """Attempts to read app list from fallback config file using grep."""
    logging.info(f"Attempting fallback: Reading app list from {filepath}")
    if not Path(filepath).is_file():
         logging.warning(f"Fallback config file not found: {filepath}"); return None
    grep_cmd = ['grep', '^export app=', filepath]
    success, stdout, stderr = run_command(grep_cmd, check=False, needs_sudo=True)
    if not success or not stdout:
        logging.error(f"Failed to grep fallback file or no matching line: {filepath}")
        if stderr: logging.error(f"Stderr from grep: {stderr.strip()}")
        return None
    app_line = next((line for line in stdout.strip().splitlines() if line.startswith("export app=")), None)
    if not app_line:
         logging.error(f"Matching line found by grep, but processing failed? Line: {stdout.strip()}"); return None
    try:
        raw_value = app_line.split('=', 1)[1].strip()
        if len(raw_value) > 1 and ((raw_value.startswith("'") and raw_value.endswith("'")) or \
                                   (raw_value.startswith('"') and raw_value.endswith('"'))):
            return raw_value[1:-1]
        else: return raw_value
    except IndexError:
        logging.error(f"Failed to parse value from grep output line: {app_line}"); return None

# is_apt_package_installed (remains the same)
def is_apt_package_installed(package_name):
    logging.info(f"Checking if APT package '{package_name}' is installed...")
    try:
        cmd = ['dpkg-query', '-W', '-f=${Status}', package_name]
        success, stdout, stderr = run_command(cmd, check=False, needs_sudo=False)
        if success and "ok installed" in stdout: return True
        if stderr and "no packages found matching" not in stderr.lower():
            logging.warning(f"dpkg-query stderr for {package_name}: {stderr.strip()}")
        return False
    except Exception as e:
        logging.warning(f"Could not check package status for {package_name}: {e}"); return False

# clean_app_list (remains the same)
def clean_app_list(raw_list_str):
    if not raw_list_str: return []
    cleaned_items = []
    potential_items = re.split(r'\s+', raw_list_str.strip())
    for item in potential_items:
        item = item.strip()
        if len(item) > 1 and ((item.startswith("'") and item.endswith("'")) or \
                              (item.startswith('"') and item.endswith('"'))):
            item = item[1:-1]
        if not item or item.startswith('root@') or item.endswith('#') or item.endswith('$'):
             logging.debug(f"Ignoring potential junk item during cleaning: '{item}'"); continue
        cleaned_items.append(item)
    return cleaned_items

# read_state_file_raw / write_state_file_raw (remains the same)
def read_state_file_raw(filepath):
    if not filepath.exists(): return None
    try:
        with open(filepath, 'r') as f: return f.read().strip()
    except Exception as e:
        logging.warning(f"Could not read state file {filepath}: {e}. Treating as non-existent."); return None
def write_state_file_raw(filepath, content):
    try:
        filepath.parent.mkdir(parents=True, exist_ok=True)
        with open(filepath, 'w') as f: f.write(content)
        logging.info(f"Updated state file: {filepath}")
    except Exception as e: logging.error(f"ERROR: Could not write state file {filepath}: {e}")

# --- Installation Helper Functions ---

def install_local_deb(deb_path):
    """Installs a local .deb file using apt."""
    logging.info(f"Attempting apt installation of {deb_path.name}...")
    apt_install_cmd = ['apt', 'install', '-y', str(deb_path)]
    # apt install needs sudo
    success, _, _ = run_command(apt_install_cmd, needs_sudo=True)
    if success:
        logging.info(f"Successfully installed .deb: {deb_path.name}")
        return True
    else:
        logging.error(f"ERROR: Failed to install .deb file: {deb_path.name}")
        return False

def install_local_binary(binary_path, target_dir=Path("/usr/local/bin")):
    """Makes a local file executable and moves it to target_dir."""
    logging.info(f"Installing binary file: {binary_path.name} to {target_dir}")
    # Ensure executable permission (no sudo needed in /tmp)
    try:
        binary_path.chmod(binary_path.stat().st_mode | 0o111) # Add execute bits
        logging.info(f"Set execute permission on {binary_path.name}")
    except Exception as e:
         logging.error(f"ERROR: Failed to set execute permission on {binary_path}: {e}")
         return False # Cannot proceed if cannot make executable

    # Move to target directory (needs sudo)
    target_path = target_dir / binary_path.name
    logging.info(f"Attempting to move '{binary_path.name}' to '{target_path}'")
    mv_cmd = ['mv', str(binary_path), str(target_path)]
    move_success, _, _ = run_command(mv_cmd, needs_sudo=True)
    if move_success:
        logging.info(f"Successfully installed binary/executable to {target_path}")
        return True
    else:
        logging.error(f"ERROR: Failed to move executable to {target_path}. Check permissions?")
        return False

def install_local_archive(archive_path, temp_extract_base):
    """Extracts .tar.gz, finds executable, and installs it."""
    logging.info(f"Processing archive file: {archive_path.name}")
    # Create unique extraction dir within the temp base dir
    extract_dir = temp_extract_base / f"extract_{archive_path.stem.replace('.tar', '')}_{int(time.time())}"
    try:
        extract_dir.mkdir(parents=True, exist_ok=True)
    except Exception as e:
        logging.error(f"ERROR: Failed to create extraction directory {extract_dir}: {e}")
        return False

    logging.info(f"Extracting '{archive_path.name}' to {extract_dir}...")
    # Tar doesn't need sudo
    tar_cmd = ['tar', '-xzf', str(archive_path), '-C', str(extract_dir)]
    extract_success, _, _ = run_command(tar_cmd, needs_sudo=False)

    if not extract_success:
        logging.error(f"ERROR: Failed to extract archive: {archive_path.name}")
        # Cleanup extraction dir? Handled by main TemporaryDirectory context.
        return False

    logging.info("Extraction successful. Searching for executable...")
    # (Executable finding logic remains same)
    executable_candidates = [e for e in extract_dir.rglob('*') if e.is_file() and os.access(e, os.X_OK)]
    found_executable = None
    if not executable_candidates:
        logging.error(f"ERROR: No executable files found in extracted archive: {archive_path.name}")
        return False
    elif len(executable_candidates) == 1:
        found_executable = executable_candidates[0]
        logging.info(f"Found unique executable: {found_executable.name}")
    else:
        logging.warning(f"Multiple executables found: {[e.name for e in executable_candidates]}. Trying best match.")
        archive_stem = archive_path.stem.replace('.tar', ''); best_match = None
        for c in executable_candidates:
             if c.name == archive_stem: best_match = c; break
        if best_match: found_executable = best_match; logging.info(f"Selected executable matching archive name: {found_executable.name}")
        else: found_executable = executable_candidates[0]; logging.warning(f"Could not determine best match, using first found: {found_executable.name}")

    if found_executable:
        # Install the found executable using the binary installer function
        return install_local_binary(found_executable)
    else:
        # Already logged error if no executable found
        return False

def handle_url_item(url, temp_dir_path):
    """Downloads a URL, identifies the file, and installs it based on type."""
    logging.info(f"Processing URL: {url}")
    download_dir = temp_dir_path / f"download_{int(time.time())}" # Unique subdir for this download
    try:
        download_dir.mkdir(parents=True, exist_ok=True)
    except Exception as e:
        logging.error(f"ERROR: Failed to create download directory {download_dir}: {e}")
        return False

    logging.info(f"Downloading to {download_dir}...")
    # Use --content-disposition, add --trust-server-names? Maybe not needed if CD works.
    # Use -P prefix directory for wget
    wget_cmd = ['wget',
                '--content-disposition', # Try to get filename from header
                # '--trust-server-names', # Alternative/backup naming strategy from URL redirection
                '--timeout=60', '--tries=3', '-P', str(download_dir), url]
    download_success, _, stderr = run_command(wget_cmd, needs_sudo=False)

    if not download_success:
        logging.error(f"ERROR: Failed to download URL: {url}")
        # Cleanup download dir? Handled by main TemporaryDirectory context.
        return False

    # Find the downloaded file(s) in the specific download_dir
    try:
        downloaded_files = list(download_dir.iterdir())
    except Exception as e:
        logging.error(f"ERROR: Failed to list download directory {download_dir}: {e}")
        return False

    if not downloaded_files:
        # Check stderr for clues like "unable to deduce filename"
        if stderr and "unable to deduce filename" in stderr.lower():
             logging.error(f"ERROR: wget could not determine filename for URL {url}")
        else:
             logging.error(f"ERROR: Download command succeeded but no file found in {download_dir} for URL {url}")
        return False
    elif len(downloaded_files) > 1:
        logging.warning(f"WARNING: Multiple files found in {download_dir}: {[f.name for f in downloaded_files]}. Attempting to process the first one.")
        # Potentially add better logic here if needed
        downloaded_file_path = downloaded_files[0]
    else:
        downloaded_file_path = downloaded_files[0]
        logging.info(f"Download successful. Found file: {downloaded_file_path.name}")

    # --- Process the single downloaded file ---
    file_name_lower = downloaded_file_path.name.lower()
    install_result = False

    if file_name_lower.endswith('.deb'):
        install_result = install_local_deb(downloaded_file_path)
    elif file_name_lower.endswith('.tar.gz'):
        # Pass the main temp dir path for extraction subdirs
        install_result = install_local_archive(downloaded_file_path, temp_dir_path)
    elif file_name_lower.endswith(('.bin', '.appimage')):
        install_result = install_local_binary(downloaded_file_path)
    else:
        logging.error(f"ERROR: Downloaded file has unknown/unhandled type: {downloaded_file_path.name}")
        install_result = False # Explicitly mark as failure

    # Don't need to clean up downloaded_file_path, it's inside the main TemporaryDirectory

    return install_result


# --- Main Logic ---
logging.info("Script started.")

# 1. Determine App List Source (Env Var or Fallback)
# (Logic remains the same)
app_list_str_raw = os.getenv('app')
source_description = "environment variable 'app'"
if not app_list_str_raw:
    logging.info("Environment variable 'app' is empty or not set. Attempting fallback.")
    app_list_str_raw = get_app_list_from_fallback(FALLBACK_CONFIG_FILE)
    if app_list_str_raw is None:
         app_list_str_raw = ""; source_description = f"fallback file {FALLBACK_CONFIG_FILE} (failed or empty)"
    else:
         source_description = f"fallback file {FALLBACK_CONFIG_FILE}"; logging.info(f"Using app list from fallback source.")
else: logging.info(f"Using app list from environment variable 'app'.")
current_app_raw_stripped = app_list_str_raw.strip()

# 2. Compare with Last Run's Raw State for fast exit
# (Logic remains the same)
logging.info(f"Reading previous state from {STATE_FILE}")
previous_app_raw = read_state_file_raw(STATE_FILE)
if not current_app_raw_stripped:
    logging.info(f"No applications specified via {source_description}.")
    if previous_app_raw is not None and previous_app_raw != "":
        logging.info("Removing state file as current desired state is empty.")
        try: STATE_FILE.unlink()
        except OSError as e: logging.warning(f"Could not remove state file {STATE_FILE}: {e}")
    else: logging.info("State file already reflects empty environment (or doesn't exist).")
    logging.info("Exiting cleanly (no apps specified)."); sys.exit(0)
elif current_app_raw_stripped == previous_app_raw:
    logging.info(f"App list from {source_description} unchanged since last run. Exiting cleanly."); sys.exit(0)
else:
    logging.info(f"App list from {source_description} has changed. Updating state file and proceeding.")
    write_state_file_raw(STATE_FILE, current_app_raw_stripped)

# 3. Clean the App List
# (Logic remains the same)
logging.info(f"Raw app list content being processed: \"{current_app_raw_stripped}\"")
current_app_items = clean_app_list(current_app_raw_stripped)
logging.info(f"Cleaned application list for processing: {current_app_items}")
if not current_app_items:
     logging.warning("No valid application items found after cleaning. Check source content. Exiting."); sys.exit(0)

# 4. Use a temporary directory for all downloads/extractions in this run
with tempfile.TemporaryDirectory(prefix="app_install_") as temp_run_dir:
    logging.info(f"Using temporary directory: {temp_run_dir}")
    temp_run_path = Path(temp_run_dir)

    # 5. Process Each Item (Revised Logic)
    for item in current_app_items:
        logging.info(f"--- Processing item: {item} ---")
        install_success = False # Reset for each item
        item_type = "unknown" # Determined later or based on source type

        # Check if item is a URL
        if item.startswith(('http://', 'https://')):
            item_type = "url"
            install_success = handle_url_item(item, temp_run_path)
        else:
            # --- Handle non-URL items (APT, Flatpak) ---
            # Is it a Flatpak ID?
            if item.count('.') >= 2 and '/' not in item and \
               not any(item.lower().endswith(s) for s in ['.deb','.tar.gz','.bin','.appimage']): # Basic check
                item_type = "flatpak"
                logging.info(f"Attempting Flatpak install: {item}")
                flatpak_cmd = ['flatpak', 'install', '-y', '--noninteractive', 'flathub', item]
                success, _, stderr = run_command(flatpak_cmd, needs_sudo=True) # Handles sudo
                if success: install_success = True
                else:
                    logging.error(f"ERROR: Failed Flatpak install command for {item}.")
                    if stderr: logging.error(f"Flatpak stderr: {stderr.strip()}")

            # Assume APT package if it's simple name (no dots, no slashes, known suffixes)
            elif '.' not in item and '/' not in item and \
                 not any(item.lower().endswith(s) for s in ['.deb','.tar.gz','.bin','.appimage']):
                if is_apt_package_installed(item):
                      logging.info(f"APT package '{item}' is already installed.")
                      # Add to success list here directly? Or let the summary handle it?
                      # Let's add it here to be explicit and avoid failure reporting.
                      success_list.append(f"{item} (already installed)")
                      install_success = True # Mark as handled successfully
                      item_type = "apt (already installed)" # Clarify type
                else:
                      item_type = "apt"
                      logging.info(f"Attempting to install APT package: {item}")
                      success, _, _ = run_command(['apt', 'install', '-y', item], needs_sudo=True)
                      if success: install_success = True
                      else: logging.error(f"ERROR: Failed to install APT package: {item}")
            else:
                # Neither URL, Flatpak, nor simple APT name - Unknown local item?
                item_type = "unknown"
                logging.warning(f"Item '{item}' is not a URL, Flatpak ID, or simple APT package name. Cannot process.")
                # Explicitly fail unknown types
                failure_list.append(f"{item} (unknown type)")
                any_failure = True


        # 6. Update Result Lists based on processing outcome
        # Avoid adding duplicates if already marked 'already installed'
        already_logged_success = any(f"{item} (already installed)" in s for s in success_list)

        if install_success and not already_logged_success:
            # Log success (installation functions already log details)
             success_list.append(f"{item} ({item_type})")
        elif not install_success and not already_logged_success and item_type != "unknown":
            # Log failure only if install failed, wasn't already installed, and wasn't unknown type
             failure_list.append(f"{item} ({item_type})")
             any_failure = True
        # else: Either already logged as success, or was unknown type (already logged failure)

        logging.info(f"--- Finished processing item: {item} ---\n")

# --- End of processing loop ---

# Temporary directory automatically cleaned up

# 7. Report Results
# (Logic remains same)
logging.info("----- Installation Summary -----")
# ... (rest of reporting logic) ...
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


# 8. Set Exit Status
# (Logic remains same)
if any_failure:
    logging.error("Script finished with failures.")
    sys.exit(1)
else:
    logging.info("Script finished successfully.")
    sys.exit(0)
