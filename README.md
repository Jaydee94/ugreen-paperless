# ugreen-paperless

An Ansible role and playbook collection to install and deploy paperless-ngx on an Ugreen NAS (or other Linux hosts) using Docker Compose.

This repository contains an opinionated role `paperless` that installs Docker, renders a Docker Compose stack (paperless-ngx + Postgres + Redis + Paperless-AI) and brings it up. It's intended for small/home NAS systems and can be adapted for other environments.

## Contents

- `roles/paperless/` — An Ansible role that deploys paperless-ngx with Docker Compose. Includes defaults, templates, tasks and handlers.
- `inventory/` — example inventory layout (hosts, group_vars, host_vars).
- `ugreen-paperless.yml` — example playbook to run the role against your NAS.

## Quick start

1. Clone this repository to your Ansible control machine.
2. Make sure your target NAS is reachable via SSH and you have a user with sudo privileges.
3. Set host-specific variables (at minimum change DB password) in `inventory/host_vars/<your-nas>/` or in your playbook.
4. Run the playbook:

```bash
ansible-playbook -i inventory/hosts.yml ugreen-paperless.yml
```

### Deploying Paperless-AI to Kubepi

To deploy the AI service to a separate host (e.g., `kubepi`), use the dedicated playbook:

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
- `paperless_ai_enabled` — whether to include the paperless-ai service (default: true).
- `paperless_ai_port` — port on host mapped to the paperless-ai web UI (default: 3000).

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
ansible-playbook -i inventory/hosts.yml ugreen-paperless.yml --ask-vault-pass --ask-become-pass

```

I included an example file `inventory/host_vars/ugreen-nas/vault.yml.example` showing the variable name and placeholder. Copy it to `vault.yml` and encrypt it as shown above.

## Customization

- To use a different Postgres or Paperless image tag, override `paperless_db_image` and `paperless_image` in `host_vars` or your playbook.
- To integrate with an existing reverse proxy or TLS setup, place the compose stack behind your reverse proxy and map ports accordingly.

## Troubleshooting

- If Docker installation fails on your NAS, check the OS and package manager. Many NAS devices run custom or trimmed-down OSes; you may need to adapt the role's install steps.
- If the role falls back to the CLI and containers don't start, check `docker-compose` or `docker compose` availability and inspect `docker-compose logs`.

## Accessing Paperless after deployment

After running the playbook, open your browser and go to:

    http://<NAS-IP>:<paperless_http_port>

- `<NAS-IP>` is the IP address of your Ugreen NAS.
- `<paperless_http_port>` is the port you set in your variables (default: 8000).

Example (default):

    http://192.168.1.100:8000

Log in with the credentials you set during initial setup, or follow the Paperless documentation to create your first user if prompted.

## Accessing Paperless-AI

If enabled, Paperless-AI is available at:

    http://<NAS-IP>:<paperless_ai_port>

Example (default):

    http://192.168.1.100:3000

You will need to configure your AI provider settings (OpenAI, Ollama, etc.) in the Paperless-AI interface upon first login.

## License

See `LICENSE` in the repository root.

