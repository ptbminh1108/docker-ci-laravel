#!/bin/bash

# Ensure the script exits on failure
set -e

# Load environment variables
if [ -f .env ]; then
    source .env
else
    echo "Error: .env file not found."
    exit 1
fi

# Validate required variables
REQUIRED_VARS=("DEV_USER" "GITHUB_REPO_URL" "GITHUB_RUNNER_TOKEN")
for VAR in "${REQUIRED_VARS[@]}"; do
    if [ -z "${!VAR}" ]; then
        echo "Error: $VAR is not set in .env file."
        exit 1
    fi
done

echo "Setting up GitHub Actions Runner for user: $DEV_USER"

# 1. Ensure Persistent Secrets Directory Exists
# This solves the issue of losing .env during auto-deploy
SECRETS_DIR="/home/$DEV_USER/secrets"
echo "Configuring secrets storage at $SECRETS_DIR..."

if [ ! -d "$SECRETS_DIR" ]; then
    sudo -u "$DEV_USER" mkdir -p "$SECRETS_DIR"
fi

# Copy local .env.repository to secrets dir if it exists locally
if [ -f .env.repository ]; then
    echo "Copying .env.repository to $SECRETS_DIR for persistence..."
    sudo cp .env.repository "$SECRETS_DIR/.env.repository"
    sudo chown "$DEV_USER":"$DEV_USER" "$SECRETS_DIR/.env.repository"
    sudo chmod 600 "$SECRETS_DIR/.env.repository"
else
    echo "Warning: .env.repository not found locally. Please ensure it is placed in $SECRETS_DIR manually."
fi

# 2. Setup Runner Directory
RUNNER_DIR="/home/$DEV_USER/actions-runner"
if [ -d "$RUNNER_DIR" ]; then
    echo "Runner directory already exists at $RUNNER_DIR. Skipping download/config."
    echo "If you want to reinstall, please delete the directory or stop the service first."
else
    echo "Creating runner directory..."
    sudo -u "$DEV_USER" mkdir -p "$RUNNER_DIR"
    
    # 3. Download and Extract Runner
    # Using the version from your snippet: 2.331.0
    RUNNER_VERSION="2.331.0"
    
    echo "Downloading GitHub Actions Runner v$RUNNER_VERSION..."
    sudo -u "$DEV_USER" bash -c "cd $RUNNER_DIR && curl -o actions-runner-linux-x64-${RUNNER_VERSION}.tar.gz -L https://github.com/actions/runner/releases/download/v${RUNNER_VERSION}/actions-runner-linux-x64-${RUNNER_VERSION}.tar.gz"
    
    echo "Extracting runner..."
    sudo -u "$DEV_USER" bash -c "cd $RUNNER_DIR && tar xzf ./actions-runner-linux-x64-${RUNNER_VERSION}.tar.gz"
    
    # 4. Configure Runner
    # We strip the oauth2 token part from GITHUB_REPO_URL if present to get the clean base URL for config
    # Assuming GITHUB_REPO_URL is like https://oauth2:TOKEN@github.com/user/repo.git or just https://github.com/user/repo.git
    # The config --url expects the repo page url (e.g. https://github.com/user/repo)
    
    # Simple extraction of https://github.com/user/repo from the git url
    # Removing .git suffix and potential credentials
    CLEAN_REPO_URL=$(echo "$GITHUB_REPO_URL" | sed -E 's/https:\/\/.*@/https:\/\//' | sed 's/\.git$//')
    
    echo "Configuring runner for $CLEAN_REPO_URL..."
    # --unattended: Don't ask for prompts
    # --replace: Replace existing runner with same name if exists
    sudo -u "$DEV_USER" bash -c "cd $RUNNER_DIR && ./config.sh --url $CLEAN_REPO_URL --token $GITHUB_RUNNER_TOKEN --unattended --replace"
    
    # 5. Install as Background Service
    # This ensures it runs in background and persists after reboot/terminal close
    echo "Installing runner as a systemd service..."
    cd "$RUNNER_DIR"
    sudo ./svc.sh install "$DEV_USER"
    sudo ./svc.sh start
    
    echo "Runner installed and started successfully!"
fi

echo "Status of runner service:"
cd "$RUNNER_DIR"
sudo ./svc.sh status
