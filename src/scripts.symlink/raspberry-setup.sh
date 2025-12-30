#!/bin/bash

# --- Usage Check ---
if [ -z "$1" ]; then
    echo "Usage: $0 <path_to_boot_partition>"
    echo "Example: $0 /media/$USER/bootfs"
    exit 1
fi

BOOT_MOUNT="$1"
HOSTNAME="phone"

# --- Safety Check ---
if [ ! -f "$BOOT_MOUNT/cmdline.txt" ]; then
    echo "Error: '$BOOT_MOUNT' does not look like a Raspberry Pi boot partition."
    echo "       Could not find cmdline.txt."
    exit 1
fi

echo "----------------------------------------------------"
echo "Raspberry Pi Headless Configuration Tool"
echo "Target:   $BOOT_MOUNT"
echo "Hostname: $HOSTNAME"
echo "----------------------------------------------------"

# --- 0. Configure Hostname ---
echo "[+] Setting hostname to '$HOSTNAME'..."
if grep -q "systemd.hostname=$HOSTNAME" "$BOOT_MOUNT/cmdline.txt"; then
    echo "    Hostname already set."
else
    sed -i "s/$/ systemd.hostname=$HOSTNAME/" "$BOOT_MOUNT/cmdline.txt"
fi

# --- 1. Credentials ---
read -p "Enter username: " RPI_USER
read -s -p "Enter password: " RPI_PASS
echo ""
echo "----------------------------------------------------"

# --- 2. Wi-Fi ---
read -p "Enter Wi-Fi SSID: " WIFI_SSID
read -s -p "Enter Wi-Fi Password: " WIFI_PASS
echo ""
echo "----------------------------------------------------"

# --- 3. Enable SSH ---
echo "[+] Enabling SSH..."
touch "$BOOT_MOUNT/ssh"

# --- 4. Configure User ---
echo "[+] Configuring user '$RPI_USER'..."
ENCRYPTED_PASS=$(echo "$RPI_PASS" | openssl passwd -6 -stdin)
echo "$RPI_USER:$ENCRYPTED_PASS" > "$BOOT_MOUNT/userconf.txt"

# --- 5. Configure Wi-Fi (Robust Method) ---
echo "[+] Configuring Wi-Fi (calculating hex key)..."

# Write the header first
cat <<EOF > "$BOOT_MOUNT/wpa_supplicant.conf"
country=CA
ctrl_interface=DIR=/var/run/wpa_supplicant GROUP=netdev
update_config=1

EOF

# Use wpa_passphrase to generate the hex block and append it
# This handles the unicode characters safely.
wpa_passphrase "$WIFI_SSID" "$WIFI_PASS" >> "$BOOT_MOUNT/wpa_supplicant.conf"

# Optional: Remove the commented out plaintext password that wpa_passphrase adds
sed -i '/#psk=/d' "$BOOT_MOUNT/wpa_supplicant.conf"

# --- 6. Sync and Finish ---
echo "[+] Syncing changes to disk..."
sync

echo "----------------------------------------------------"
echo "Done! You may now safely eject the card."
