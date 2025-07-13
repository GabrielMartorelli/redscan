#!/bin/bash
set -euo pipefail

# Colors for logs and icons
GREEN="\033[0;32m"    # ✅ Success/info messages
RED="\033[0;31m"      # ❌ Error messages
BLUE="\033[0;34m"     # 🔷 Action/process messages
YELLOW="\033[1;33m"   # ⚠️ Warning messages
RESET="\033[0m"

# Function to print info messages in green
log_info() {
  echo -e "${GREEN}[*]${RESET} ${GREEN}$1${RESET}"
}

# Function to print error messages in red
log_error() {
  echo -e "${RED}[*]${RESET} ${RED}$1${RESET}"
}

# Function to print action/process messages in blue
log_action() {
  echo -e "${BLUE}[*]${RESET} ${BLUE}$1${RESET}"
}

# Function to print warning messages in yellow
log_warn() {
  echo -e "${YELLOW}[*]${RESET} ${YELLOW}$1${RESET}"
}

# Check if the script is running with root privileges
if [[ "$EUID" -ne 0 ]]; then
  log_error "This script must be run with elevated privileges. Please run with sudo."
  exit 1
fi

# Prompt for sudo password to activate sudo cache
sudo -v

# Keep sudo session alive until the script finishes to avoid repeated password prompts
( while true; do sudo -n true; sleep 60; done ) 2>/dev/null &

# Verify if rustscan is installed
if ! command -v rustscan &> /dev/null; then
  log_error "Rustscan is not installed. Please install it to continue."
  exit 1
fi

# Verify if nmap is installed
if ! command -v nmap &> /dev/null; then
  log_error "Nmap is not installed. Please install it to continue."
  exit 1
fi

# Store current working directory in a variable
CUR_DIR="$(pwd)"
log_info "Current directory where the script is running: $CUR_DIR"

# Prompt the user to enter the target IP address
read -p "Enter the target IP: " IP

# Validate if the IP input is not empty
if [[ -z "$IP" ]]; then
  log_error "IP cannot be empty. Aborting."
  exit 1
fi

# Remove old output files to avoid prompts and permission issues
rm -f Ports.txt allPorts.txt

# Inform the user that Rustscan is starting
log_action "Running Rustscan on IP $IP..."

# Run Rustscan on all ports (1-65535) and filter only open ports, save to Ports.txt
rustscan --no-banner -a "$IP" -r 1-65535 --ulimit 5000 | grep "^Open" > Ports.txt

# Set file permission for Ports.txt
chmod 644 Ports.txt

# Check if Ports.txt is empty (no open ports found)
if [[ ! -s Ports.txt ]]; then
  log_warn "No open ports found on IP $IP."
  exit 1
fi

# Show the open ports found
log_info "Open ports found (saved in Ports.txt):"
cat Ports.txt

# Extract port numbers from Ports.txt (portion after ':') and prepare comma-separated list for Nmap
ports=$(awk -F':' '/^Open/ {print $2}' Ports.txt | tr '\n' ',' | sed 's/,$//')

# Wait 20 seconds to avoid conflicts between Rustscan and Nmap executions
sleep 20

# Ask the user if they want to use the SYN scan (-sS) flag for Nmap
read -p "Use -sS flag (SYN scan) in Nmap? (y/n): " use_sS
if [[ "$use_sS" =~ ^[Yy]$ ]]; then
  scan_flag="-sS"
else
  # If not SYN scan, ask about TCP Connect scan (-sT)
  read -p "Use -sT flag (TCP Connect scan) in Nmap? (y/n): " use_sT
  if [[ "$use_sT" =~ ^[Yy]$ ]]; then
    scan_flag="-sT"
  else
    scan_flag=""
  fi
fi

# Ask the user if they want to skip host discovery (-Pn)
read -p "Use -Pn flag in Nmap? (y/n): " use_pn

# Ask if the user wants to use the banner grabbing script (--script=banner)
read -p "Use banner grabbing script (--script=banner)? (y/n): " use_banner

# Initialize an array to hold Nmap arguments
nmap_args=()

# Add chosen scan flag if any
if [[ -n "$scan_flag" ]]; then
  nmap_args+=("$scan_flag")
fi

# Add common Nmap scripts and version detection flags
nmap_args+=("-sCV")

# Add -Pn flag if selected
if [[ "$use_pn" =~ ^[Yy]$ ]]; then
  nmap_args+=("-Pn")
fi

# Add banner grabbing script if selected
if [[ "$use_banner" =~ ^[Yy]$ ]]; then
  nmap_args+=("--script=banner")
fi

# Add ports, target IP, and output file parameters
nmap_args+=("-p" "$ports" "$IP" "-oN" "allPorts.txt")

# Inform user about the Nmap execution
log_action "Running Nmap on ports $ports..."

# Run Nmap with all selected options
nmap "${nmap_args[@]}"

# Set permissions for the Nmap output file, ignoring errors
chmod 644 allPorts.txt 2>/dev/null || true

# Final informational message
log_info "Nmap scan completed. Results saved in allPorts.txt"
