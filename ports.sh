#!/bin/bash
set -euo pipefail  # Configure bash to exit on errors, treat unset variables as errors, and fail if any command in a pipe fails

# Colors for logs and icons to improve terminal output readability
GREEN="\033[0;32m"    # ✅ green for informational messages
RED="\033[0;31m"      # ❌ red for errors
BLUE="\033[0;34m"     # 🔷 blue for actions
YELLOW="\033[1;33m"   # ⚠️ yellow for warnings
RESET="\033[0m"       # Reset to default color

# Functions to print formatted and colored messages to the terminal
log_info() {
  echo -e "${GREEN}[*]${RESET} ${GREEN}$1${RESET}"
}

log_error() {
  echo -e "${RED}[*]${RESET} ${RED}$1${RESET}"
}

log_action() {
  echo -e "${BLUE}[*]${RESET} ${BLUE}$1${RESET}"
}

log_warn() {
  echo -e "${YELLOW}[*]${RESET} ${YELLOW}$1${RESET}"
}

# Function to ask for Nmap flags only once at the start
ask_flags() {
  read -p "Do you want to use the -sS flag (SYN scan) in Nmap? (y/n): " use_sS
  if [[ "$use_sS" =~ ^[Yy]$ ]]; then
    scan_flag="-sS"
  else
    read -p "Do you want to use the -sT flag (TCP Connect scan) in Nmap? (y/n): " use_sT
    if [[ "$use_sT" =~ ^[Yy]$ ]]; then
      scan_flag="-sT"
    else
      scan_flag=""  # No specific scan flag selected
    fi
  fi

  # Ask about the -Pn flag to skip ping, useful when ICMP is blocked by firewalls
  read -p "Do you want to use the -Pn flag in Nmap? (y/n): " use_pn
  # Ask if the banner grab script should be used for service banner collection
  read -p "Do you want to use the banner grab script (--script=banner)? (y/n): " use_banner
}

# Check if the script is running with root privileges
if [[ "$EUID" -ne 0 ]]; then
  log_error "This script must be run with elevated privileges. Run with sudo."
  exit 1
fi

# Request sudo password upfront to avoid multiple prompts during execution
sudo -v

# Function to keep sudo session alive throughout script execution by refreshing timestamp every 60 seconds
keep_sudo_alive() {
  while true; do sudo -n true; sleep 60; done
}
keep_sudo_alive &           # Run in background
SUDO_PID=$!                # Save the PID to kill it later
trap 'kill "$SUDO_PID"' EXIT  # Ensure the background process is killed when the script exits

# Check if rustscan is installed, tool used for fast port scanning
if ! command -v rustscan &> /dev/null; then
  log_error "Rustscan is not installed. Please install it to continue."
  exit 1
fi

# Check if nmap is installed, tool used for detailed scanning on found ports
if ! command -v nmap &> /dev/null; then
  log_error "Nmap is not installed. Please install it to continue."
  exit 1
fi

CUR_DIR="$(pwd)"  # Save current directory
log_info "Current directory where the script is running: $CUR_DIR"

# Test write permission on the current directory by creating a temporary file
if ! touch test.tmp 2>/dev/null; then
  log_error "No write permission in the current directory ($CUR_DIR)."
  exit 1
else
  rm -f test.tmp  # Remove the temporary file after testing
fi

# Ask the user to input the target IP or the path to a file containing a list of IPs
read -p "Enter the target IP or path to IP list file: " TARGET

# If TARGET is a file, load the list of IPs; otherwise, treat TARGET as a single IP
if [[ -f "$TARGET" ]]; then
  # Check if the file is not empty
  if [[ ! -s "$TARGET" ]]; then
    log_error "File $TARGET is empty. Aborting."
    exit 1
  fi
  mapfile -t IP_LIST < "$TARGET"  # Read file lines into IP_LIST array
else
  IP_LIST=("$TARGET")  # Put single IP into the array
fi

# Check if there is at least one IP to scan
if [[ ${#IP_LIST[@]} -eq 0 ]]; then
  log_error "No IPs to scan. Aborting."
  exit 1
fi

# Ask Nmap flags once before starting the loop through the IPs
ask_flags

# Loop through each IP in the list to perform the scan
for IP in "${IP_LIST[@]}"; do
  IP=$(echo "$IP" | xargs) # Remove leading/trailing whitespace

  # Skip empty IP entries
  if [[ -z "$IP" ]]; then
    log_warn "Empty IP found in the list. Skipping."
    continue
  fi

  # Validate IP format (simple IPv4 format check without range validation)
  if ! [[ "$IP" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; then
    log_warn "IP '$IP' is invalid. Skipping."
    continue
  fi

  log_action "Starting scan for IP $IP..."

  # Ping test - only warn if no reply, but continue scanning (useful if ICMP is blocked)
  if ! ping -c 1 -W 1 "$IP" &> /dev/null; then
    log_warn "IP $IP does not respond to ping, but will continue scanning."
  fi

  # Create safe filenames based on IP by removing suspicious characters
  SAFE_IP=$(echo "$IP" | tr -cd '[:alnum:]._-')
  PORTS_FILE="Ports-${SAFE_IP}.txt"      # File for open ports found by Rustscan
  NMAPP_FILE="allPorts-${SAFE_IP}.txt"   # File for Nmap scan results

  rm -f "$PORTS_FILE" "$NMAPP_FILE"  # Remove old files to avoid confusion

  log_action "Running Rustscan on IP $IP..."
  # Run rustscan with timeout to avoid hangs, saving only lines starting with "Open"
  if ! rustscan --no-banner -a "$IP" -r 1-65535 --ulimit 5000 --timeout 3000 | grep "^Open" > "$PORTS_FILE"; then
    log_warn "Rustscan failed for $IP. Skipping this IP."
    continue
  fi
  chmod 664 "$PORTS_FILE"  # Set read/write permissions for owner and group
  log_info "Rustscan finished for $IP"

  # Check if any open ports were found
  if [[ ! -s "$PORTS_FILE" ]]; then
    log_warn "[*] No open ports found on IP $IP. Skipping to next IP."
    continue
  fi

  # Display the open ports found
  log_info "Open ports found on $IP (saved in $PORTS_FILE):"
  cat "$PORTS_FILE"

  # Extract only the port numbers to pass to Nmap, separated by commas
  ports=$(awk -F':' '/^Open/ {print $2}' "$PORTS_FILE" | tr '\n' ',' | sed 's/,$//')

  sleep 2  # Small delay to avoid overwhelming system or target

  # Build array of Nmap arguments based on user's flag selections
  nmap_args=()
  if [[ -n "$scan_flag" ]]; then
    nmap_args+=("$scan_flag")
  fi
  nmap_args+=("-sCV")  # Default scan with service/version detection and default scripts
  if [[ "$use_pn" =~ ^[Yy]$ ]]; then
    nmap_args+=("-Pn")  # Skip host discovery ping
  fi
  if [[ "$use_banner" =~ ^[Yy]$ ]]; then
    nmap_args+=("--script=banner")  # Enable banner grab script
  fi
  nmap_args+=("-p" "$ports" "$IP" "-oN" "$NMAPP_FILE")  # Define ports, target IP, and output file

  log_action "Running Nmap on ports $ports for $IP..."
  # Run Nmap with the built arguments
  if ! nmap "${nmap_args[@]}"; then
    log_warn "Nmap failed for $IP."
  fi
  chmod 664 "$NMAPP_FILE" 2>/dev/null || true  # Adjust permissions, ignore errors

  log_info "Nmap scan finished for $IP. Results saved in $NMAPP_FILE"
  echo  # Blank line to visually separate logs per IP
done
