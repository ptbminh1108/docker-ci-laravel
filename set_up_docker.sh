#!/bin/bash

# Ensure the script exits on failure
set -e

# Check if .env file exists
if [ ! -f .env ]; then
    echo "Error: .env file not found. Please copy .env.example to .env and update the values."
    exit 1
fi

# Load environment variables
source .env

# Validate required variables
if [ -z "$DEV_USER" ] || [ -z "$DEV_PASSWORD" ]; then
    echo "Error: DEV_USER and DEV_PASSWORD variables are required in .env file."
    exit 1
fi

echo "Starting Docker setup..."

# 1. Install Docker
if command -v docker &> /dev/null; then
    echo "Docker is already installed."
else
    echo "Installing Docker..."
    curl -fsSL https://get.docker.com -o get-docker.sh
    sudo sh get-docker.sh
    rm get-docker.sh
    echo "Docker installed successfully."
fi

# 2. Create Dev User
if id "$DEV_USER" &>/dev/null; then
    echo "User $DEV_USER already exists."
else
    echo "Creating user $DEV_USER..."
    # Create user with home directory, shell /bin/bash
    sudo useradd -m -s /bin/bash "$DEV_USER"
    
    # Set the password
    echo "$DEV_USER:$DEV_PASSWORD" | sudo chpasswd
    echo "User $DEV_USER created."
fi

# 3. Add users to docker group
echo "Configuring docker group permissions..."

# Ensure docker group exists (it should after docker install)
if ! getent group docker > /dev/null; then
    sudo groupadd docker
fi

# Add the dev user to the docker group
sudo usermod -aG docker "$DEV_USER"
echo "Added $DEV_USER to docker group."

# Optionally add the current running user to the docker group if it's not the same and not root
CURRENT_USER=$(whoami)
if [ "$CURRENT_USER" != "root" ] && [ "$CURRENT_USER" != "$DEV_USER" ]; then
    sudo usermod -aG docker "$CURRENT_USER"
    echo "Added current user ($CURRENT_USER) to docker group."
fi

echo "Setup completed successfully!"
echo "Please remember to log out and back in (or restart the session) for group membership changes to take effect."
