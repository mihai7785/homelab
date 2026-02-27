# ADR-007: Observability Stack

**Date:** 2026-02
**Status:** Accepted

## Context

Phase 5 required a comprehensive observability implementation covering metrics, logs,
traces, and alerting. The goal was to achieve full visibility into both cluster
infrastructure and application behaviour, and to establish the patterns used by
enterprise platform teams.

## Decision

Deploy the kube-prometheus-stack Helm chart as the foundation, extended with Loki for
log aggregation and Grafana as the unified visualisation layer.

**Stack:**
- **Prometheus** — metrics collection and storage
- **Grafana** — dashboards and unified query interface
- **Alertmanager** — alert routing and grouping
- **Loki + Promtail** — log aggregation and shipping
- **kube-state-metrics** — Kubernetes object state metrics
- **node-exporter** — host-level metrics (CPU, memory, disk, network)
- **Jaeger** (optional) — distributed tracing for application-level spans

## Rationale

### Why kube-prometheus-stack over individual components

kube-prometheus-stack is a curated Helm chart that bundles Prometheus, Grafana,
Alertmanager, kube-state-metrics, and node-exporter with pre-configured scrape
configs, recording rules, and default dashboards for every Kubernetes component.
Installing these separately would require manually wiring scrape targets, RBAC,
ServiceMonitors, and dashboard imports.

The chart is maintained by the Prometheus community and is the standard approach
in production Kubernetes environments. Understanding how to configure and operate
it — values overrides, custom ServiceMonitors, PrometheusRules — is directly
applicable interview knowledge.

### Why Loki over Elasticsearch/OpenSearch

Loki uses a label-based index (similar to Prometheus) rather than a full-text index.
This makes it significantly cheaper to operate — no large JVM heap, no index
maintenance, lower storage requirements. The trade-off is that Loki cannot do
full-text search across log content; you query by labels and then filter within
matching log streams.

For a homelab that primarily wants to correlate logs with metrics (same Grafana
datasource, same time range), the label-based approach is sufficient. Loki's
LogQL query language is also similar enough to PromQL that learning one transfers
to the other.

### Why a unified Grafana for metrics and logs

Grafana supports both Prometheus and Loki as datasources simultaneously. A single
Grafana dashboard can show a CPU spike from Prometheus and the corresponding error
logs from Loki side by side, correlated by time. This unified view is the standard
in production platform teams — separate UIs for metrics and logs create cognitive
overhead during incidents.

### ServiceMonitor pattern for application metrics

Rather than adding Prometheus scrape targets via static configuration, all services
expose a ServiceMonitor custom resource. Prometheus discovers these automatically
via label selectors. This means adding observability to a new service requires
only adding a ServiceMonitor manifest alongside the service — no central Prometheus
configuration file changes. This is the production Kubernetes approach.

The AI Gateway, k8sgpt operator, and ArgoCD all expose ServiceMonitors. The pattern
is consistent across every monitored component.

## NFS for Grafana persistence

Grafana dashboard state (user-created dashboards, data source configurations,
alert rules) is stored on an NFS PVC from the Synology NAS. This means Grafana
configuration survives pod restarts and node failures. Prometheus data uses a
local-path PVC on the server node for performance — metric data can be
reconstructed if lost, making durability less critical than for Grafana state.

## Consequences

- All platform components expose ServiceMonitors. New applications added to the
  platform should follow the same pattern.
- Alertmanager is configured but alert routing targets (Telegram, email) are not
  committed to the repository — these are environment-specific and should be
  configured via a Kubernetes Secret referencing the values file.
- Loki is deployed in single-binary mode (not microservices), which is appropriate
  for homelab scale but would need to be replaced with the distributed mode for
  production workloads ingesting >50GB/day of logs.
- Grafana dashboards defined in the Grafana UI are persisted via NFS but not
  version-controlled. A future improvement is to export dashboards as JSON and
  commit them to `monitoring/dashboards/` for GitOps-managed provisioning.