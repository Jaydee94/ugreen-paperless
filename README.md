# ugreen-paperless

An Ansible role and playbook collection to install and deploy paperless-ngx and supporting services on an Ugreen NAS (or other Linux hosts) using Docker Compose.

This repository contains a set of opinionated roles that install Docker, render Docker Compose stacks, and bring them up. It's intended for small/home NAS systems and Raspberry Pi hosts, and can be adapted for other environments.

## Architecture overview

The setup is split across two hosts:

| Host | Roles deployed | Purpose |
|------|---------------|---------|
| `ugreen-nas` | `paperless`, `gotify`, `monitoring` | Ugreen NAS: runs paperless-ngx + Gotify notifications + monitoring stack |
| `kubepi` | `paperless-ai`, `scanner-pi`, `opencode` | Raspberry Pi: standalone Paperless-AI, scanner automation, and OpenCode |

## Contents

- `roles/paperless/` — Deploys paperless-ngx (+ Postgres + Redis, optionally inline Paperless-AI) with Docker Compose.
- `roles/gotify/` — Deploys a [Gotify](https://gotify.net/) push-notification server with Docker Compose.
- `roles/paperless-ai/` — Deploys [Paperless-AI](https://github.com/clusterzx/paperless-ai) as a standalone service on a separate host (e.g., `kubepi`).
- `roles/scanner-pi/` — Configures a Raspberry Pi as a scan station: installs SANE/scanbd, mounts the paperless consume SMB share, and deploys a scan-to-PDF script.
- `roles/opencode/` — Deploys [OpenCode](https://github.com/opencode-ai/opencode) (an AI coding assistant) as a Docker container.
- `roles/monitoring/` — Deploys a lightweight monitoring stack (Prometheus + Grafana + Node Exporter + cAdvisor) with Docker Compose.
- `inventory/` — Example inventory layout (hosts, group_vars, host_vars).
- `ugreen-paperless.yml` — Playbook that deploys `paperless`, `gotify`, and `monitoring` to `ugreen-nas`.
- `paperless-ai.yml` — Playbook that deploys `paperless-ai`, `scanner-pi`, and `opencode` to `kubepi`.

## Quick start

1. Clone this repository to your Ansible control machine.
2. Make sure your target NAS is reachable via SSH and you have a user with sudo privileges.
3. Set host-specific variables (at minimum change DB password) in `inventory/host_vars/<your-nas>/` or in your playbook.
4. Run the playbook:

```bash
ansible-playbook -i inventory/hosts.yml ugreen-paperless.yml --ask-vault-pass --ask-become-pass --ask-pass
```

### Deploying to Kubepi (Paperless-AI + scanner + OpenCode)

To deploy the AI service, scanner automation, and OpenCode to a separate host (e.g., `kubepi`), use the dedicated playbook:

```bash
ansible-playbook -i inventory/hosts.yml paperless-ai.yml --ask-vault-pass --ask-become-pass --ask-pass
```

Make sure to configure the `kubepi` host in `inventory/hosts.yml` and ensure SSH access is available.


## Role: `paperless` (summary)

The role performs the following high-level steps:

- Installs Docker (Debian/Ubuntu or RedHat family) and ensures the docker service is running.
- Creates a system user and base directories for paperless data, media, and database.
- Renders `docker-compose.yml` and `.env` from templates into `{{ paperless_base_dir }}`.
- Attempts to use the `community.docker.docker_compose` Ansible module to bring up the stack; falls back to `docker compose up -d` or `docker-compose up -d`.

Key configurable variables are in `roles/paperless/defaults/main.yml`. Important ones:

- `paperless_base_dir` — where the compose file, data and media directories are placed (default: `/opt/paperless`).
- `paperless_db_password` — database password (change this before deploying).
- `paperless_http_port` — port on host mapped to the paperless web UI (default: 8000).
- `paperless_ai_enabled` — whether to include the paperless-ai service inline in the compose stack (default: false).
- `paperless_ai_port` — port on host mapped to the paperless-ai web UI (default: 3000).

## Role: `gotify` (summary)

Deploys a [Gotify](https://gotify.net/) push-notification server using Docker Compose.

Key configurable variables are in `roles/gotify/defaults/main.yml`. Important ones:

- `gotify_base_dir` — base directory for Gotify files (default: `/opt/gotify`).
- `gotify_port` — host port mapped to the Gotify web UI (default: 8085).
- `gotify_image` — Docker image to use (default: `gotify/server:2.9.1`).
- `gotify_password` — initial admin password (default: `admin`; change before deploying).

## Role: `paperless-ai` (summary)

Deploys [Paperless-AI](https://github.com/clusterzx/paperless-ai) as a standalone Docker Compose service on a dedicated host. This role also installs Docker.

Key configurable variables are in `roles/paperless-ai/defaults/main.yml`. Important ones:

- `paperless_ai_base_dir` — base directory (default: `/opt/paperless-ai`).
- `paperless_ai_port` — host port mapped to the Paperless-AI web UI (default: 3000).
- `paperless_ai_image` — Docker image (default: `clusterzx/paperless-ai:3.0.9`).
- `paperless_url` — URL of the main paperless-ngx instance (default: `http://ugreen-nas:8000`).

## Role: `scanner-pi` (summary)

Configures a Raspberry Pi (or similar Linux host) as a scan station that feeds scanned documents directly into paperless-ngx's consume directory over SMB.

- Installs ImageMagick, SANE, scanbd, and cifs-utils.
- Mounts the paperless consume SMB share at `paperless_mount_point`.
- Configures scanbd to trigger a scan-to-PDF script when the scanner button is pressed.

Key configurable variables are in `roles/scanner-pi/defaults/main.yml`. Important ones:

- `paperless_smb_share` — SMB share path for the paperless consume directory.
- `paperless_smb_user` / `paperless_smb_password` — credentials for the SMB mount (store password in Ansible Vault).
- `paperless_mount_point` — local mount point (default: `/mnt/paperless-consume`).

## Role: `opencode` (summary)

Deploys [OpenCode](https://github.com/opencode-ai/opencode), a terminal-based AI coding assistant, as a Docker container with a web interface.

Key configurable variables are in `roles/opencode/defaults/main.yml`. Important ones:

- `opencode_install_dir` — install directory (default: `/opt/opencode`).
- `opencode_port` — host port mapped to the OpenCode web UI (default: 8080).
- `opencode_image` / `opencode_version` — Docker image and tag (default: `ghcr.io/anomalyco/opencode:latest`).
- `opencode_server_password` — optional password to protect the web interface.

## Role: `monitoring` (summary)

Deploys a lightweight monitoring stack (Prometheus + Grafana + Node Exporter + cAdvisor) via Docker Compose on `ugreen-nas`. This gives you basic insight into the performance and availability of all services running on the NAS and optionally any remote hosts (e.g. `kubepi`).

| Component | Purpose |
|-----------|---------|
| Prometheus | Collects and stores metrics |
| Grafana | Visualises metrics; Prometheus datasource is provisioned automatically |
| Node Exporter | Exposes host-level system metrics (CPU, memory, disk, network) |
| cAdvisor | Exposes per-container metrics for all Docker containers on the host |

Key configurable variables are in `roles/monitoring/defaults/main.yml`. Important ones:

- `monitoring_base_dir` — base directory for the stack (default: `/opt/monitoring`).
- `prometheus_port` — host port for Prometheus UI (default: `9090`).
- `grafana_port` — host port for Grafana UI (default: `3001`).
- `grafana_admin_password` — initial Grafana admin password (default: `admin`; **change before deploying**).
- `prometheus_retention_time` — how long Prometheus keeps metrics (default: `15d`).
- `monitoring_extra_targets` — list of additional Prometheus scrape targets for remote hosts (see `roles/monitoring/README.md`).

## Security and secrets

- Do not store secrets in plaintext in the repository. Use Ansible Vault (`ansible-vault`) or environment-specific `host_vars` files that are not committed to source control.
- Change the default `paperless_db_password` and other credentials before deploying to any non-test environment.

### Storing the DB password with Ansible Vault

Recommended pattern: create an encrypted host_vars file per-host. Example path used in this repo:

```
inventory/host_vars/ugreen-nas/vault.yml
```

Two common ways to create the vaulted variable:

1) Create an encrypted file interactively (recommended):

```bash
ansible-vault create inventory/host_vars/ugreen-nas/vault.yml
# then add the YAML inside, e.g.:
# paperless_db_password: supersecret-passw0rd
```

2) Encrypt a single string and paste into a plaintext file or vars file:

```bash
ansible-vault encrypt_string 'supersecret-passw0rd' --name 'paperless_db_password'
# The command prints an encrypted value you can paste into host_vars or group_vars.
```

Run the playbook and provide the vault password at runtime, or configure a vault identity in your Ansible config:

```bash 
ansible-playbook -i inventory/hosts.yml ugreen-paperless.yml --ask-vault-pass --ask-become-pass --ask-pass

```

I included an example file `inventory/host_vars/ugreen-nas/vault.yml.example` showing the variable name and placeholder. Copy it to `vault.yml` and encrypt it as shown above.

## Customization

- To use a different Postgres or Paperless image tag, override `paperless_db_image` and `paperless_image` in `host_vars` or your playbook.
- To integrate with an existing reverse proxy or TLS setup, place the compose stack behind your reverse proxy and map ports accordingly.

## Troubleshooting

- If Docker installation fails on your NAS, check the OS and package manager. Many NAS devices run custom or trimmed-down OSes; you may need to adapt the role's install steps.
- If the role falls back to the CLI and containers don't start, check `docker-compose` or `docker compose` availability and inspect `docker-compose logs`.

## Accessing services after deployment

### Paperless-ngx (ugreen-nas)

After running the `ugreen-paperless.yml` playbook, open your browser and go to:

    http://<NAS-IP>:<paperless_http_port>

- `<NAS-IP>` is the IP address of your Ugreen NAS.
- `<paperless_http_port>` is the port you set in your variables (default: 8000).

Example (default):

    http://192.168.1.100:8000

Log in with the credentials you set during initial setup, or follow the Paperless documentation to create your first user if prompted.

### Gotify (ugreen-nas)

Gotify is available at:

    http://<NAS-IP>:<gotify_port>

Example (default):

    http://192.168.1.100:8085

Log in with the admin credentials set via `gotify_password`. Change the default password after first login.

### Paperless-AI (kubepi)

After running the `paperless-ai.yml` playbook, Paperless-AI is available at:

    http://<KUBEPI-IP>:<paperless_ai_port>

Example (default):

    http://192.168.1.101:3000

You will need to configure your AI provider settings (OpenAI, Ollama, etc.) in the Paperless-AI interface upon first login.

### OpenCode (kubepi)

OpenCode is available at:

    http://<KUBEPI-IP>:<opencode_port>

Example (default):

    http://192.168.1.101:8080

If `opencode_server_password` is set, you will be prompted for it on first access.

### Monitoring (ugreen-nas)

After running the `ugreen-paperless.yml` playbook, the monitoring stack is available on the NAS:

| Service | URL | Purpose |
|---------|-----|---------|
| Prometheus | `http://<NAS-IP>:9090` | Metrics query and status |
| Grafana | `http://<NAS-IP>:3001` | Dashboards and visualisation |

Log in to Grafana with username `admin` and the password set in `grafana_admin_password`. The Prometheus datasource is provisioned automatically. To get started, import community dashboards from [grafana.com/grafana/dashboards](https://grafana.com/grafana/dashboards/):

- **Node Exporter Full** (ID `1860`) — detailed host metrics
- **Docker Containers** (ID `11600`) — per-container resource usage

## License

See `LICENSE` in the repository root.

