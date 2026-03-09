# Role: `monitoring`

Deploys a monitoring stack on the target host using Docker Compose. The stack consists of:

| Service | Image | Purpose |
|---------|-------|---------|
| [Prometheus](https://prometheus.io/) | `prom/prometheus` | Metrics storage (TSDB) with remote_write receiver |
| [Grafana Alloy](https://grafana.com/docs/alloy/latest/) | `grafana/alloy` | Metrics collection, scraping, and HTTP service health probes |
| [Grafana](https://grafana.com/) | `grafana/grafana` | Metrics visualisation and dashboards |
| [Node Exporter](https://github.com/prometheus/node_exporter) | `prom/node-exporter` | Host system metrics (CPU, memory, disk, network) |
| [cAdvisor](https://github.com/google/cadvisor) | `gcr.io/cadvisor/cadvisor` | Docker container metrics |

**Grafana Alloy** handles all metric scraping (Node Exporter, cAdvisor, remote targets) and HTTP health probing, then forwards everything to Prometheus via `remote_write`. Prometheus is kept solely for TSDB storage with the `--web.enable-remote-write-receiver` flag.

Node Exporter and cAdvisor run without exposed host ports — they are only accessible inside the `monitoring_net` Docker network and scraped by Alloy.

## Key variables (`defaults/main.yml`)

| Variable | Default | Description |
|----------|---------|-------------|
| `monitoring_base_dir` | `/opt/monitoring` | Directory for compose file, config, and named volumes |
| `monitoring_user` / `monitoring_uid` | `monitoring` / `1200` | System user owning the files |
| `prometheus_image` | `prom/prometheus:v3.2.1` | Prometheus Docker image |
| `prometheus_port` | `9090` | Host port for the Prometheus UI |
| `prometheus_retention_time` | `15d` | TSDB retention period |
| `alloy_image` | `grafana/alloy:v1.7.5` | Grafana Alloy Docker image |
| `grafana_image` | `grafana/grafana:11.5.2` | Grafana Docker image |
| `grafana_port` | `3001` | Host port for the Grafana UI |
| `grafana_admin_password` | `admin` | Initial Grafana admin password (**change before deploying**) |
| `node_exporter_image` | `prom/node-exporter:v1.9.1` | Node Exporter Docker image |
| `cadvisor_image` | `gcr.io/cadvisor/cadvisor:v0.51.0` | cAdvisor Docker image |
| `monitoring_extra_targets` | `[]` | Additional remote scrape targets (Node Exporter on other hosts) |
| `monitoring_probe_targets` | `[]` | HTTP service health probe targets (see below) |
| `monitoring_probe_timeout` | `5s` | Timeout for HTTP health probes; increase for slow-starting services |

## Monitoring remote hosts

To collect metrics from remote hosts (e.g. `kubepi`) you need to run Node Exporter on those hosts and add them as extra targets. Alloy will scrape them and forward the metrics to Prometheus.

Example `host_vars` or playbook variable:

```yaml
monitoring_extra_targets:
  - job_name: kubepi-node
    host: kubepi
    port: 9100
```

## Service health monitoring

Alloy's built-in blackbox component performs HTTP health probes against configured service URLs every 30 seconds. The results are stored in Prometheus under the `blackbox` job and visualised in the **Services Health** dashboard.

Example `host_vars` configuration:

```yaml
monitoring_probe_targets:
  - name: paperless
    url: http://ugreen-nas:8000
  - name: gotify
    url: http://ugreen-nas:8085
  - name: prometheus
    url: http://ugreen-nas:9090/-/healthy
  - name: grafana
    url: http://ugreen-nas:3001/api/health
  - name: paperless-ai
    url: http://kubepi:3000
  - name: opencode
    url: http://kubepi:8080
```

Each target is probed with an HTTP GET request. The following Prometheus metrics are generated:

| Metric | Description |
|--------|-------------|
| `probe_success{job="blackbox", instance="<name>"}` | `1` if the service is up, `0` if down |
| `probe_duration_seconds{job="blackbox", instance="<name>"}` | HTTP response time in seconds |
| `probe_http_status_code{job="blackbox", instance="<name>"}` | HTTP status code returned |

## Pre-built dashboards

The role ships five Grafana dashboards that are provisioned automatically:

| Dashboard | File | Description |
|-----------|------|-------------|
| **Services Health** | `services-health.json` | HTTP probe status, response times, and uptime history for all configured services |
| **Applications Overview** | `applications-overview.json` | CPU, memory, and network usage per application (Paperless, Gotify, Paperless-AI, OpenCode) |
| **Node Exporter Full** | `node-exporter-full.json` | Detailed host system metrics |
| **Docker Containers** | `docker-containers.json` | Per-container resource usage |
| **PostgreSQL Database** | `postgresql.json` | Database metrics (requires `postgres_exporter` target) |

## Accessing services

After running the playbook, the following UIs are available on the host where the role was applied:

| Service | URL |
|---------|-----|
| Prometheus | `http://<host>:9090` |
| Grafana | `http://<host>:3001` |

Log in to Grafana with username `admin` and the password set in `grafana_admin_password`. The Prometheus datasource is provisioned automatically.

## Security

- Store `grafana_admin_password` in Ansible Vault. Do **not** leave the default `admin` password in place.
- Node Exporter and cAdvisor do not expose ports on the host; they are only reachable within the `monitoring_net` Docker network.
- Alloy does not expose any ports to the host by default.
