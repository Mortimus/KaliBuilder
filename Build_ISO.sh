#!/bin/bash

start_time=$(date +%s.%N)
TIMESTAMP=$(date +"%Y-%m-%d %H:%M:%S")
# -------- Configuration --------
# Paths
OUT_DIR="$HOME"                                                        # Output for logs, iso, etc
TMP_DIR="/dev/shm"                                                     # Temporary directory
LB_DEFAULT="$OUT_DIR/live-build-config"                                # Live build directory
CONFIG_DIR="$LB_DEFAULT/kali-config"                                   # Live build config directory
BASE_DIR="$CONFIG_DIR/variant-mycompany"                               # Where the live-build files for mycompany exist
CISO_ROOT="$BASE_DIR/includes.chroot"                                  # Root of the custom ISO
MOTD_DIR="$CISO_ROOT/etc/"                                             # Directory to store MOTD
OVPN_DIR="$CISO_ROOT/etc/openvpn"                                      # Directory to store OVPN files
OVPN_TAR="$OVPN_DIR/client.conf"                                       # OVPN file to write to
PRESEED="$BASE_DIR/hooks/normal/06-failsafe-user.chroot"               # Preseed for ISO creation
ROOT_PATH="$(dirname "$0")"                                            # Base folder of git repo
DEFAULT_BOILERPLATE="$ROOT_PATH/variant-mycompany"                     # Default boilerplate to use
DICT_PATH="$ROOT_PATH/mycompany-common.txt"                            # Dictionary for password generation
TMP_ISO="$LB_DEFAULT/images"                                           # Live build ISO folder output
SSH_PATH="Engineer-Keys/SSH Public Keys.txt"                           # SSH Keys path from content repo
TMP_NESSUS_DIR="$TMP_DIR/nessus"                                       # Temporary directory for extracting Nessus deb
TMP_NESSUS="$TMP_DIR/nessus.deb"                                       # Temporary Nessus download location
NESSUS_PATH="$BASE_DIR/packages.chroot"                                # Where to place Nessus deb
#NESSUS_PATH="$CONFIG_DIR/common/packages.chroot"                      # Where to place Nessus deb (hack to get it installed)
LOG_FILE="$OUT_DIR/client_deployment.log"                              # Log file for auditing
DEBUG_LOG="$OUT_DIR/$TIMESTAMP-build.log"                              # Debug log for auditing
#USE_MIRROR="true"                                                     # Set to true to use the mirror
MIRROR_URL="https://mirrors.jevincanders.net/kali/"                    # Mirror for debugging
MIRROR_PATH="$LB_DEFAULT/.mirror"                                      # Mirror path for live-build
#KALI_DISTRO="kali-rolling"                                            # Kali distro to use
KALI_DISTRO="kali-last-snapshot"                                       # Kali distro to use
# Repos
KALI_CUSTOM="https://gitlab.com/kalilinux/build-scripts/live-build-config.git"
CONTENT_REPO="git@github.com:mycompany/private-deploy.git"
# URLS
NESSUS_DOWNLOAD="https://www.tenable.com/downloads/api/v2/pages/nessus/files/Nessus-latest-debian10_amd64.deb"

# -------- Functions --------
# Function to handle errors and exit
handle_error() {
  echo "Error: $1"
  exit 1
}
# Generate a random password for breakglass account
generate_password() {
  # generate password

  # Check that $DICT_PATH exists Fixes #29
  if [ ! -f "$DICT_PATH" ]; then
    handle_error "Dictionary file '$DICT_PATH' not found."
  fi

  # Count the number of lines in the dictionary file
  num_lines=$(wc -l < "$DICT_PATH")

  # loop to pick 4 random words to create a password
  for i in {1..4}; do
    # Generate a random number within the range of lines in the file
    random_line=$(shuf -i 1-$num_lines -n 1)

    # Get the word at the randomly selected line
    random_pass+="$(sed -n "${random_line}p" "$DICT_PATH")_"
  done

  # remove the trailing underscore
  random_pass=${random_pass%_}
}

# Download Nessus DEB and fix it for package manager and place it in the chroot
place_nessus() {
  # nessus doesn't abide by debian rules :( so we have to fix it
  # need to run as root to fix some warning
  sudo wget -O $TMP_NESSUS "$NESSUS_DOWNLOAD"
  sudo mkdir "$TMP_NESSUS_DIR"
  sudo dpkg-deb --raw-extract "$TMP_NESSUS" "$TMP_NESSUS_DIR"
  # sudo sed "s/Package: Nessus/Package: nessus/" -i "$TMP_NESSUS_DIR/DEBIAN/control"
  pkg=$(sed -n 's/^Package: *//p' "$TMP_NESSUS_DIR/DEBIAN/control")
  arch=$(sed -n 's/^Architecture: *//p' "$TMP_NESSUS_DIR/DEBIAN/control")
  version=$(sed -n 's/^Version: *//p' "$TMP_NESSUS_DIR/DEBIAN/control")

  # fix package name, keeping only allowed characters: lower case letters (a-z),
  # digits (0-9), plus (+) and minus (-) signs, and periods (.)
  pkg=$(echo $pkg | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9+.-]*//g')
  sudo sed -i "s/^Package: .*/Package: $pkg/" "$TMP_NESSUS_DIR/DEBIAN/control"

  # check if nessus_path exists
  if [ ! -d "$NESSUS_PATH" ]; then
    echo "Creating Nessus path: $NESSUS_PATH"
    sudo mkdir "$NESSUS_PATH"
  fi
  sudo dpkg-deb -b "$TMP_NESSUS_DIR" "$NESSUS_PATH/${pkg}_${version}_${arch}.deb"
  sudo chown -R kali:kali "$NESSUS_PATH"
  sudo chmod 775 "$NESSUS_PATH"
  # cleanup
  # rm -rf $TMP_NESSUS_DIR
  # rm -rf $TMP_NESSUS
}

# Clone the SSH keys from the repo and assign them to all users
pull_ssh() {
  git clone $CONTENT_REPO "$TMP_DIR/content" || handle_error "Failed to clone Content repo."
  cp "$TMP_DIR/content/$SSH_PATH" "$CISO_ROOT/root/.ssh/authorized_keys"
  # clean up
  # rm -rf $TMP_DIR/content
}

# Cleanup potential artifacts
cleanup() {
  sudo rm -rf "$LB_DEFAULT"     # Live build
  sudo rm -rf "$OUT_DIR"/*.iso  # Old ISO files
  sudo rm -rf "$TMP_NESSUS_DIR"
  sudo rm -rf "$TMP_NESSUS"
  sudo rm -rf "$BASE_DIR"
  sudo rm -rf "$TMP_DIR/content"
}

# Check if NOT in a Tmux session
if [[ -z "$TMUX" ]]; then
  echo "ERROR: This script should be run inside a Tmux session." >&2
  exit 1 # Exit with an error code
fi

# Check for SSH Agent
if ssh-add -l 2>&1 | grep -q "The agent has no identities."; then
  echo "WARNING: SSH Agent does not have any identities, please ensure you have your SSH key in the SSH agent so that we can clone private repos."
  #exit 1
fi

# Check if repo is up to date
# Fetch updates silently
git fetch origin >/dev/null 2>&1 || handle_error "Cannot fetch updates from origin."

# Check if 'main' is behind 'origin/main'
if [[ "$(git rev-list --count HEAD..origin/main 2>/dev/null)" -gt 0 ]]; then
  echo "Your repo is out of date, please run 'git pull' to update it before creating an ISO."
  exit 1
fi

# Check for correct number of arguments
if [ "$#" -lt 1 ]; then
  handle_error "Usage: $0 <ovpn_file> [<boilerplate>]"
fi

# Root won't have the SSH agent by default config, so let's just do this
if [[ $EUID -eq 0 ]]; then
   echo "This script must NOT be run as root (it will prompt for sudo when needed)." 
   exit 1
fi

# Assign arguments to variables
OVPN_FILE="$1"
BOILERPLATE="$2"

if [ ! -f "$OVPN_FILE" ]; then
  handle_error "OVPN file '$OVPN_FILE' not found."
fi

# Check if BOILERPLATE is provided, if not use the default
if [ -z "$BOILERPLATE" ]; then
  BOILERPLATE="$DEFAULT_BOILERPLATE"
fi

if [ ! -d "$BOILERPLATE" ]; then
  handle_error "$BOILERPLATE doesn't exist"
fi

# Check if live-build is installed
if ! command -v lb &> /dev/null; then
  handle_error "live-build is not installed. Please install it first."
fi

# Extract Client Name from the OVPN file
CLIENT_NAME=$(awk -F= '/^# OVPN_ACCESS_SERVER_USERNAME=/ {print $2}' "$OVPN_FILE")
if [ -z "$CLIENT_NAME" ]; then
  handle_error "Client name not found in OVPN file."
fi
echo "Using $CLIENT_NAME as client name."

# Ensure an SSH agent is in use so we have access to MyCompany's Repo's
ssh-add -l >/dev/null 2>&1 || handle_error "SSH Agent not ready or has no keys."

# move to known location
# cd $OUT_DIR

# remove old ISO's if existing
echo "Removing old artifacts..."
cleanup

# Clone kali updater
git clone $KALI_CUSTOM "$LB_DEFAULT" || handle_error "Cannot clone Kali repo."
# Set mirror
if [ "$USE_MIRROR" = "true" ]; then
  echo "Using mirror: $MIRROR_URL"
  echo $MIRROR_URL > "$MIRROR_PATH"
else
  echo "Using default mirror."
fi
# if [ -d "/home/kali/live-build-config" ]; then
#   echo "live-build-config already exists not cloning"
# else
#   git clone $KALI_CUSTOM || handle_error "Cannot clone Kali repo."
# fi

# Copy the boilerplate to the new variant-mycompany directory for use
cp -R $BOILERPLATE "$CONFIG_DIR/" || handle_error "Failed to copy boilerplate."

# Install Nessus
place_nessus

# Place SSH Keys
pull_ssh

# Place the OpenVPN file
cp "$OVPN_FILE" "$OVPN_TAR" || handle_error "Failed to move ovpn file."

# Set MOTD
figlet "$CLIENT_NAME" > "$MOTD_DIR/motd"

# Set breakglass password
generate_password

echo "Setting break glass password to $random_pass"

sed -i 's/\(PASSWORD="\)[^"]*/\1'"$random_pass"'/' "$PRESEED"

# Do the actual build
echo "Running build.sh --verbose --variant mycompany"
# cd $LB_DEFAULT
env -i bash "$LB_DEFAULT/build.sh" -d $KALI_DISTRO --verbose --variant mycompany | tee -a "$DEBUG_LOG"
end_time=$(date +%s.%N)

duration=$(echo "$end_time - $start_time" | bc -l)

# move the ISO before we delete the folder
# Naming format MyCompany_VM_CLIENT_04_21.iso
iso_name="MyCompany_VM_"
iso_name+=$CLIENT_NAME
iso_name+="_$(date +%m_%d).iso"
iso_name=$(echo $iso_name | tr ' ' '_') # Remove spaces
mv "$TMP_ISO"/*.iso "$OUT_DIR/$iso_name" || handle_error "Failed to move ISO file."
echo "ISO generated at $OUT_DIR/$iso_name"
echo "In case of emergency use breakglass:$random_pass to troubleshoot the system."
# echo "Build time: $duration seconds"
MD5="$(md5sum $OUT_DIR/$iso_name | awk '{print $1}')"
echo "MD5: $MD5"
# cleanup old directory - we do this at start, will remove this in case investigation is needed
# sudo rm -rf /home/kali/live-build-config
echo "$TIMESTAMP - Client $CLIENT_NAME deployed, ISO: $iso_name MD5: $MD5 OVPN: $OVPN_FILE Boilerplate: $BOILERPLATE Breakglass: $random_pass BuildTime: $duration" >> "$LOG_FILE" || handle_error "Failed to write to log file."

echo "Client '$CLIENT_NAME' deployment complete."
exit 0
