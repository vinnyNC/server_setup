#!/bin/bash
#
# Module: docker
# Category: install
#
# Installs Docker and Docker Compose.
#

# --- Strict Mode ---
set -euo pipefail

echo "Installing Docker..."

# Check if Docker is already installed
if command -v docker >/dev/null 2>&1; then
    echo "Docker is already installed. Version: $(docker --version)"
else
    echo "Installing Docker from official repository..."
    
    # Update package database
    export DEBIAN_FRONTEND=noninteractive
    apt-get update -y
    
    # Install prerequisites
    apt-get install -y ca-certificates curl gnupg lsb-release
    
    # Add Docker's official GPG key
    mkdir -p /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    
    # Set up the repository
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
    
    # Install Docker Engine
    apt-get update -y
    apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    
    # Start and enable Docker service
    systemctl start docker
    systemctl enable docker
    
    echo "Docker installed successfully!"
fi

# Check if Docker Compose is available
if docker compose version >/dev/null 2>&1; then
    echo "Docker Compose is available. Version: $(docker compose version)"
else
    echo "Warning: Docker Compose plugin not found."
fi

echo "Docker installation complete."
echo "You may want to add users to the 'docker' group to run Docker without sudo."

# Brief pause to show completion message
sleep 2
