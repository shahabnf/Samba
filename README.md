# 📂 Samba
Public SMB server

This script sets up a public SMB server using a Docker container. No authentication is required to access files in the SMB server. It will:

- Create the necessary host directory (if it does not already exist).
- Install Docker.
- Generate a Dockerfile and SMB configuration file.
- Build a custom Docker image.
- Map the host directory to "/mnt/share" inside the Docker container.

# 📥 Download Release
➡ [Latest Release](https://github.com/shahabnf/samba/releases)

# 📦 Installation
Navigate to the script directory and execute the following commands to make the installer executable and run the script:

```
chmod +x samba_installer.sh
./samba_installer.sh
```