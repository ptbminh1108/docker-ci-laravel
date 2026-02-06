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

# Check for .env.repository file
if [ ! -f .env.repository ]; then
    echo "Error: .env.repository file not found. Please create it with your project's environment variables."
    exit 1
fi

# Prepare the environment file for the dev user
# We copy it to the dev user's home temporarily to avoid permission issues
TMP_ENV_PATH="/home/$DEV_USER/.project_env_tmp"
cp .env.repository "$TMP_ENV_PATH"
chown "$DEV_USER" "$TMP_ENV_PATH"
chmod 600 "$TMP_ENV_PATH"

# Define the deployment commands to run as the dev user
# We use a heredoc passed to bash -c to execute multiple commands safely as the target user
sudo -u "$DEV_USER" bash <<EOF
    # Ensure strict mode and verbose logging for debugging
    set -e
    set -x

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

    echo "Setting up project environment file..."
    TMP_ENV_FILE="/home/$DEV_USER/.project_env_tmp"
    if [ -f "\$TMP_ENV_FILE" ]; then
        mv "\$TMP_ENV_FILE" .env
        # Ensure .env is writable by the container user (e.g. www-data)
        chmod 666 .env
        echo ".env file updated from .env.repository"
    else
        echo "Warning: Temporary env file not found at \$TMP_ENV_FILE. Skipping .env update."
    fi
    
    # Ensure storage and cache directories are writable
    echo "Configuring directory permissions..."
    chmod -R 777 storage bootstrap/cache 2>/dev/null || true

    echo "Running Docker Compose..."
    # Determine which docker compose command to use
    if docker compose version &>/dev/null; then
        DOCKER_COMPOSE_CMD="docker compose"
    elif command -v docker-compose &>/dev/null; then
        DOCKER_COMPOSE_CMD="docker-compose"
    else
        echo "Error: Neither 'docker compose' nor 'docker-compose' found."
        exit 1
    fi

    echo "Running Docker Compose..."
    \$DOCKER_COMPOSE_CMD -f "$DOCKER_COMPOSE_FILE" up -d --build

    echo "Running post-deployment commands..."
    
    echo "[LOG] Generating application key..."
    \$DOCKER_COMPOSE_CMD -f "$DOCKER_COMPOSE_FILE" exec -T app php artisan key:generate --force || echo "[WARNING] Application key generation failed, continuing..."

    echo "[LOG] Running migrations and seeds..."
    # Run directly to show output
    \$DOCKER_COMPOSE_CMD -f "$DOCKER_COMPOSE_FILE" exec -T app php artisan migrate --seed --force

    echo "Deployment completed successfully."
EOF
