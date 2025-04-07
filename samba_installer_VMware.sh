#!/bin/bash

# Enable "Share Folders" in VMWare machine
# Install VMware Tools
apt install open-vm-tools-desktop

# Mount hgfs
sudo vmhgfs-fuse .host:/ /mnt/hgfs -o allow_other
ls /mnt/hgfs/

# Add hgfs to fstab to mount it automatically after boot
echo ".host:/    /mnt/hgfs    fuse.vmhgfs-fuse    defaults,allow_other    0 0 " >> /etc/fstab
mount -a
systemctl daemon-reload

# Host Machine Samba Share (Change this if needed)
SHARE_PATH="/mnt/hgfs"

# Get the system's IP address
IP_ADDRESS=$(hostname -I | awk '{print $1}')

# Detect package manager
if command -v apt &>/dev/null; then
    package_manager="apt"
elif command -v yum &>/dev/null; then
    package_manager="yum"
elif command -v dnf &>/dev/null; then
    package_manager="dnf"
else
    echo "Unsupported package manager. Exiting."
    exit 1
fi

# Update system & install required packages
echo "[+] Updating system and installing dependencies..."
sudo $package_manager update -y
[[ "$package_manager" == "apt" ]] && sudo $package_manager upgrade -y
sudo $package_manager install -y curl ca-certificates software-properties-common


# Install Docker if not installed
if ! command -v docker &>/dev/null; then
    echo "[+] Installing Docker..."
    curl -fsSL https://get.docker.com | sudo bash
    sudo systemctl enable docker
    sudo systemctl start docker
fi

# Install Docker Compose Plugin if not installed
if ! command -v docker compose &>/dev/null; then
    echo "[+] Installing Docker Compose..."
    sudo $package_manager install -y docker-compose-plugin
fi

# Create Samba Share Directory
echo "[+] Creating shared directory: $SHARE_PATH..."
sudo mkdir -p "$SHARE_PATH"
sudo chmod 777 "$SHARE_PATH"

# Create Docker network
echo "[+] Creating Docker network..."
docker network create samba-net || true

# Create Dockerfile for Alpine Samba
echo "[+] Creating Dockerfile..."
mkdir -p samba-container
cat <<EOF > samba-container/Dockerfile
FROM ubuntu:latest
RUN apt update && DEBIAN_FRONTEND=noninteractive apt install -y samba
RUN mkdir -p /mnt/share && chmod 777 /mnt/share
COPY smb.conf /etc/samba/smb.conf
EXPOSE 139 445
CMD ["smbd", "-F", "--no-process-group"]
EOF

# Create Samba Config File
echo "[+] Creating Samba Configuration..."
cat <<EOF > samba-container/smb.conf
[global]
    workgroup = workgroup
    server string = Samba Server
    map to guest = bad user
    usershare allow guests = yes
    # SMB Security
    client ipc max protocol = SMB3
    client ipc min protocol = SMB2_10
    client max protocol = SMB3
    client min protocol = SMB2_10
    server max protocol = SMB3
    server min protocol = SMB2_10

[Public]
   path = /mnt/share
   browsable = yes
   writable = yes
   guest ok = yes
   public = yes
   force user = nobody
EOF

# Build and Run the Container
echo "[+] Building Samba Docker Image..."
docker build -t custom-samba samba-container
echo "[+] Running Samba Container..."
docker run -d --name samba \
  --restart unless-stopped \
  --network samba-net \
  -p 139:139 -p 445:445 \
  -v "$SHARE_PATH":/mnt/share \
  custom-samba

# Display success message
echo "[+] Samba is running! Use the following details to access:"
echo "📂 Public Share: \\$IP_ADDRESS\Public (No authentication)"

# Show container status
docker ps | grep samba
