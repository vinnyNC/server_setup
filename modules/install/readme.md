# Install Modules

This folder contains installation modules for the Enterprise Provisioner.

## Purpose

Each script in this directory is designed to automate the installation of a specific package, service, or system component. These modules are intended to be idempotent and safe to run multiple times.

## Structure

- Each module is a standalone Bash script (`*.sh`).
- Scripts should be named after the component they install (e.g., `nginx.sh`, `docker.sh`).
- Scripts must be executable.

## Guidelines

- Ensure scripts check for existing installations before proceeding.
- Log all actions to the central provisioner log.
- Exit with a non-zero status on failure.
- Add a brief description and usage notes at the top of each script.

## Example

```bash
#!/bin/bash
# nginx.sh - Installs and configures NGINX web server
# Usage: Run via the provisioner menu or manually.
```

## Adding New Modules

1. Create a new `*.sh` script in this folder.
2. Follow the guidelines above.
3. Test the script independently before using with the provisioner.

---
*For more information, see the main [provisioner README](../../readme.md).*