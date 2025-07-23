# Setup Modules

This folder contains setup modules for the Enterprise Provisioner. Each script in this directory is designed to automate a specific setup or configuration task on your server.

## Structure

- Each module is a standalone Bash script (`*.sh`).
- Modules should be idempotent and safe to run multiple times.
- Scripts are executed via the main provisioner menu.

## Guidelines for Module Authors

- Name scripts descriptively (e.g., `install_nginx.sh`).
- Include comments at the top of each script describing its purpose and usage.
- Ensure scripts exit with a non-zero status on failure.
- Use logging to `/var/log/provisioner.log` for important actions.

## Adding a New Module

1. Create a new `.sh` script in this folder.
2. Make it executable: `chmod +x your_script.sh`
3. Test the script independently before using with the provisioner.

## Example Script Header

```bash
#!/bin/bash
# install_nginx.sh
# Installs and configures NGINX web server.
# Usage: Run via the provisioner menu.
```

---

For more information, see the main [README.md](../../readme.md).