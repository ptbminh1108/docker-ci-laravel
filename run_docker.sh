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
REQUIRED_VARS=("DEV_USER" "GITHUB_REPO_URL" "REPO_NAME" "DOCKER_COMPOSE_FILE")
for VAR in "${REQUIRED_VARS[@]}"; do
    if [ -z "${!VAR}" ]; then
        echo "Error: $VAR is not set in .env file."
        exit 1
    fi
done

echo "Preparing to deploy as user: $DEV_USER"

# Check if the dev user exists
if ! id "$DEV_USER" &>/dev/null; then
    echo "Error: User $DEV_USER does not exist. Please run set_up_docker.sh first."
    exit 1
fi

# Define the deployment commands to run as the dev user
# We use a heredoc passed to bash -c to execute multiple commands safely as the target user
sudo -u "$DEV_USER" bash <<EOF
    # Ensure strict mode within the sub-shell
    set -e

    # Navigate to home directory (or intended workspace)
    cd /home/"$DEV_USER"

    echo "Checking project directory..."
    if [ ! -d "$REPO_NAME" ]; then
        echo "Cloning repository..."
        git clone "$GITHUB_REPO_URL" "$REPO_NAME"
        cd "$REPO_NAME"
    else
        echo "Repository exists. Pulling latest changes..."
        cd "$REPO_NAME"
        # Since the URL in .env includes the token, we might need to update the remote url 
        # to ensure the token is used/updated, or just pull if origin is already set correctly.
        # To be safe and support token rotation, we can update the remote origin:
        git remote set-url origin "$GITHUB_REPO_URL"
        git pull origin main || git pull origin master || git pull
    fi

    echo "Running Docker Compose..."
    # Check if docker compose (plugin) or docker-compose (standalone) is available
    if docker compose version &>/dev/null; then
        docker compose -f "$DOCKER_COMPOSE_FILE" up -d --build
    elif command -v docker-compose &>/dev/null; then
        docker-compose -f "$DOCKER_COMPOSE_FILE" up -d --build
    else
        echo "Error: Neither 'docker compose' nor 'docker-compose' found."
        exit 1
    fi

    echo "Deployment completed successfully."
EOF
