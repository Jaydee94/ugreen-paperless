# Role: `monitoring`

Deploys a lightweight monitoring stack on the target host using Docker Compose. The stack consists of:

| Service | Image | Purpose |
|---------|-------|---------|
| [Prometheus](https://prometheus.io/) | `prom/prometheus` | Metrics collection and storage |
| [Grafana](https://grafana.com/) | `grafana/grafana` | Metrics visualisation |
| [Node Exporter](https://github.com/prometheus/node_exporter) | `prom/node-exporter` | Host system metrics (CPU, memory, disk, network) |
| [cAdvisor](https://github.com/google/cadvisor) | `gcr.io/cadvisor/cadvisor` | Docker container metrics |

Node Exporter and cAdvisor run without exposed host ports — they are only accessible inside the `monitoring_net` Docker network and scraped directly by Prometheus.

## Key variables (`defaults/main.yml`)

| Variable | Default | Description |
|----------|---------|-------------|
| `monitoring_base_dir` | `/opt/monitoring` | Directory for compose file, config, and named volumes |
| `monitoring_user` / `monitoring_uid` | `monitoring` / `1200` | System user owning the files |
| `prometheus_image` | `prom/prometheus:v3.2.1` | Prometheus Docker image |
| `prometheus_port` | `9090` | Host port for the Prometheus UI |
| `prometheus_retention_time` | `15d` | TSDB retention period |
| `grafana_image` | `grafana/grafana:11.5.2` | Grafana Docker image |
| `grafana_port` | `3001` | Host port for the Grafana UI |
| `grafana_admin_password` | `admin` | Initial Grafana admin password (**change before deploying**) |
| `node_exporter_image` | `prom/node-exporter:v1.9.1` | Node Exporter Docker image |
| `cadvisor_image` | `gcr.io/cadvisor/cadvisor:v0.51.0` | cAdvisor Docker image |
| `monitoring_extra_targets` | `[]` | Additional Prometheus scrape targets (see below) |

## Monitoring remote hosts

To collect metrics from remote hosts (e.g. `kubepi`) you need to run Node Exporter on those hosts and add them as extra targets.

Example `host_vars` or playbook variable:

```yaml
monitoring_extra_targets:
  - job_name: kubepi-node
    host: kubepi
    port: 9100
```

Prometheus will then scrape `http://kubepi:9100/metrics` every 15 seconds.

## Accessing services

After running the playbook, the following UIs are available on the host where the role was applied:

| Service | URL |
|---------|-----|
| Prometheus | `http://<host>:9090` |
| Grafana | `http://<host>:3001` |

Log in to Grafana with username `admin` and the password set in `grafana_admin_password`. The Prometheus datasource is provisioned automatically — you can start creating dashboards or import community dashboards (e.g. Node Exporter Full: dashboard ID `1860`, Docker Containers: dashboard ID `11600`).

## Security

- Store `grafana_admin_password` in Ansible Vault. Do **not** leave the default `admin` password in place.
- Node Exporter and cAdvisor do not expose ports on the host; they are only reachable within the `monitoring_net` Docker network.
