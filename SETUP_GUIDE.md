# Docker Setup Guide

This guide explains how to use the `set_up_docker.sh` script to set up Docker, create a development user, and configure permissions on your **Linux server**.

## Prerequisites

- A Linux server (Ubuntu, Debian, CentOS, or Fedora).
- `curl` and `sudo` privileges.

**Note:** This script is intended for Linux environments and uses the official Docker installation script from [get.docker.com](https://get.docker.com/). It is **not** intended for macOS or Windows (Docker Desktop is recommended for those platforms).

## Step-by-Step Instructions

### 1. Configuration

1.  Copy the example environment file:

    ```bash
    cp .env.example .env
    ```

2.  Open `.env` using a text editor (e.g., `nano` or `vim`) and set your desired username and password:

    ```bash
    nano .env
    ```

    Update the following fields:
    - `DEV_USER`: The username for the new development user.
    - `DEV_PASSWORD`: The password for the new user.
    - `GITHUB_REPO_URL`: Full Git URL (e.g., `https://<token>@github.com/user/repo.git`).
    - `REPO_NAME`: Directoy name to clone the project into.
    - `DOCKER_COMPOSE_FILE`: Filename of your compose file (e.g., `docker-compose.yml`).

### 2. Make the Scripts Executable

Give the scripts execution permissions:

```bash
chmod +x set_up_docker.sh run_docker.sh
```

### 3. Run the Setup Script (One-time)

Run the setup script to install Docker and create the user. You might be prompted for your `sudo` password.

```bash
./set_up_docker.sh
```

### 4. Run the Deployment Script

Use this script effectively to deploy or update your application. It will:

1.  Switch to the `DEV_USER` context.
2.  Clone or Pull the repository defined in `.env`.
3.  Build and start the containers defined in `DOCKER_COMPOSE_FILE`.

```bash
./run_docker.sh
```

### 5. Verification

After the script completes successfully:

1.  **Docker Installation**: Verify Docker is running:

    ```bash
    docker --version
    sudo systemctl status docker
    ```

2.  **User Creation**: Verify the new user exists and is in the `docker` group:

    ```bash
    id <DEV_USER>
    # You should see something like: ... groups=...,999(docker) ...
    ```

3.  **Group Membership**:
    If you added your current user to the group, you may need to log out and log back in (or run `newgrp docker`) to apply the group changes without using `sudo` for docker commands.

## Troubleshooting

- **Existing User**: If the user already exists, the script will skip creation but ensure they are added to the docker group.
- **Docker Installed**: If Docker is already installed, the script will skip the installation step.
