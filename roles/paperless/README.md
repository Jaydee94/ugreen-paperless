# Ansible role: paperless

This role installs and deploys paperless-ngx using Docker Compose.

Default variables are in `defaults/main.yml`. Key vars:

- `paperless_base_dir` - base install directory (default: /opt/paperless)
- `paperless_media_dir`, `paperless_data_dir`, `paperless_db_dir`
- `paperless_http_port` - host port mapped to container (default: 8000)
- `paperless_db_user`, `paperless_db_password`, `paperless_db_name`
- `paperless_image`, `paperless_db_image`, `paperless_redis_image`

Usage:

Include the role in a playbook that targets your NAS host(s). Example:

```yaml
- hosts: ugreen-nas
  become: true
  roles:
    - role: paperless
      vars:
        paperless_db_password: "supersecret"
        paperless_base_dir: /srv/paperless
```

Notes:

- The role attempts to install Docker from the official Docker repositories on Debian/Ubuntu and uses yum on RedHat family.
- It prefers the `community.docker.docker_compose` module; if unavailable it falls back to `docker compose up -d` or `docker-compose up -d`.
- You should change `paperless_db_password` before deploying to production.
