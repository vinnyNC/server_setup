# Tools Modules

This folder contains provisioning modules related to various tools and utilities. Each script in this directory is designed to automate the installation or configuration of a specific tool as part of the server setup process.

## Structure

- Each module is a standalone Bash script (`*.sh`).
- Scripts should be idempotent and safe to run multiple times.
- Naming convention: `toolname.sh` (e.g., `htop.sh`, `docker.sh`).

## Usage

Modules in this folder are executed via the main provisioner script. You can select which tools to install during the interactive provisioning process.

## Adding a New Tool Module

1. Create a new script: `toolname.sh`.
2. Ensure the script is executable:  
    ```bash
    chmod +x toolname.sh
    ```
3. Follow the existing script structure for consistency.
4. Document any required environment variables or configuration at the top of your script.

## Example

```bash
#!/bin/bash
# Installs htop
apt-get update -y
apt-get install -y htop
```

## Notes

- Test your module scripts independently before adding them to the provisioning workflow.
- Update this README with any special instructions for new tools.
