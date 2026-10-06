# 🏠 Homelab — Internal Developer Platform

A self-hosted Internal Developer Platform (IDP) built on Kubernetes, following GitOps
principles. This homelab serves as both a learning environment and a portfolio
demonstrating real-world platform engineering practices.

> **Current topology (2026-10-01):** one k3s server VM (301) and three Raspberry Pi workers. Earlier demo AI integrations and the Gitea runner are retired; their source/history remains.

---

## 🎯 What This Is

A miniature IDP that mirrors enterprise platform engineering patterns at homelab scale.
The platform acts as both the **platform team** (building and maintaining the infrastructure)
and the **development team** (deploying applications onto it).

**Core principles:**
- Everything is code — infrastructure, configuration, and deployments are all version-controlled
- GitOps as the deployment model — ArgoCD reconciles cluster state from Git continuously
- AI as an input layer — AI generates manifests, humans approve, GitOps executes
- Documentation-driven — every significant decision has an Architecture Decision Record

---

## 📐 Architecture

```
┌──────────────────────────────────────────────────────────────────┐
│                    GitHub (Source of Truth)                       │
│         Infrastructure code · GitOps manifests · CI/CD           │
└────────┬─────────────────────────────────┬────────────────────────┘
         │ push triggers                   │ ArgoCD watches
         ▼                                 ▼
┌─────────────────┐              ┌─────────────────────────────────┐
│  GitHub Actions  │              │        k3s Cluster (4 nodes)    │
│  Build & push   │── GHCR images ►│                                 │
│  image to GHCR  │              │  ArgoCD · Traefik · cert-manager│
└─────────────────┘              │  Prometheus · Grafana · Loki    │
                                 │  Gitea · 1 server + 3 Pi workers│
                                 └──────────────┬──────────────────┘
                                                │
                  ┌─────────────────────────────┼──────────────────────┐
                  ▼                             ▼                      ▼
       ┌──────────────────┐        ┌─────────────────────┐  ┌─────────────────┐
       │  Synology NAS    │        │    NUC14+ (AI)       │  │  Pi-hole (DNS)  │
       │  NFS storage for │        │  Ollama · RTX 4080   │  │  *.homelab.local│
       │  persistent PVCs │        │  llama3.1:8b         │  │  resolution     │
       └──────────────────┘        │  qwen2.5-coder:7b    │  └─────────────────┘
                                   └─────────────────────┘
```

GitOps changes are reviewed in a Pull Request, then ArgoCD reconciles after merge.
The former AI Gateway API is not deployed; the local Ollama host is separate from k3s.

---

## 🖥️ Hardware

| Device | Role | Specs |
|---|---|---|
| HP Mini PC | Proxmox hypervisor — hosts k3s server VM 301 | 28 vCPU · 31GB RAM |
| ROG laptop / old Intel NUC | Additional Proxmox nodes; old NUC hosts Home Assistant | See live host inventory |
| Synology DS1525+ | NAS — NFS persistent storage for k3s PVCs | 7TB usable |
| Asus NUC14+ | AI workloads — Ollama with RTX 4080 Super eGPU | 96GB RAM · 16GB VRAM |
| Raspberry Pi ×3 | Active ARM64 k3s workers | See live node inventory |

**k3s cluster nodes:**

| Node | Role | Architecture |
|---|---|---|
| k3s-server-01 (Proxmox VM 301) | Sole server/control plane; also runs workloads | amd64 |
| raspberry-agentic-main | Worker, SSD storage label | arm64 |
| raspberry-agentic-slave1 | Worker, SD-card storage label | arm64 |
| raspberry-agentic-slave2 | Worker, SD-card storage label | arm64 |

Former worker VMs 302 and 303 have been retired. See [ADR-008](docs/adr/008-single-server-pi-workers.md) for the single-server trade-off.

---

## 🗂️ Repository Structure

```
homelab/
├── apps/
│   ├── hello-platform/     # Reference FastAPI app — Dockerfile, CI pipeline
│   └── ai-gateway/         # AI Gateway API — natural language → K8s manifests
├── gitops/
│   └── apps/               # Current ArgoCD Application manifests (App-of-Apps)
│       ├── ai-generated/   # Retained placeholder; AI Gateway is retired
│       └── */              # Manifests for deployed applications
├── infrastructure/
│   └── terraform/          # VM 301 definition; former workers 302/303 retired
├── monitoring/
│   └── dashboards/         # Grafana dashboard JSON exports
├── platform/
│   └── values/             # Helm values files for all platform components
└── docs/
    └── adr/                # Architecture Decision Records (001–008)
```

---

## ⚙️ Technology Stack

### Infrastructure & Provisioning

| Tool | Purpose |
|---|---|
| **Proxmox VE** | Hypervisor — runs all cluster VMs |
| **Terraform** | VM provisioning via Proxmox provider |
| **Ansible** | OS config, k3s bootstrap, cluster join automation |
| **Pi-hole** | Internal DNS — resolves `*.homelab.local` to MetalLB VIP |

### Kubernetes Platform

| Tool | Purpose |
|---|---|
| **k3s** | Lightweight Kubernetes — 4-node cluster (1 server, 3 Pi workers) |
| **Helm** | Package manager — deploy and configure all platform components |
| **Traefik** | Ingress controller — HTTPS termination, routing, automatic redirects |
| **MetalLB** | Load balancer — assigns external IPs to LoadBalancer services |
| **cert-manager** | Automatic TLS certificate issuance and renewal |
| **NFS provisioner** | Dynamic PVC provisioning backed by Synology NAS |

### GitOps & CI/CD

| Tool | Purpose |
|---|---|
| **ArgoCD** | GitOps engine — continuously reconciles cluster state from Git |
| **Gitea** | Self-hosted Git server — internal mirror of GitHub |
| **GitHub Actions** | CI pipelines — build, push images, update GitOps manifests |
| **GHCR** | Container registry — stores application images |

### Observability

| Tool | Purpose |
|---|---|
| **Prometheus** | Metrics collection, storage, alerting rules |
| **Grafana** | Unified dashboards — metrics and logs in one interface |
| **Loki + Promtail** | Log aggregation — all pod logs shipped and queryable |
| **Alertmanager** | Alert routing and grouping |
| **kube-state-metrics** | Kubernetes object state exposed as Prometheus metrics |

### Certificates

| Tool | Purpose |
|---|---|
| **cert-manager** | Manages certificate lifecycle in Kubernetes |
| **Private CA (homelab-ca)** | Self-signed root CA for `*.homelab.local` services |
| **CA trust distribution** | Root cert imported to browsers and OS trust stores |

### AI

| Tool | Purpose |
|---|---|
| **Ollama** | Local LLM runtime — bare metal on NUC14+, GPU-accelerated |
| **Former demo consumers** | Open WebUI, k8sgpt, and AI Gateway are no longer deployed in k3s; AI Gateway source remains under `apps/` |

---

## 🚀 Platform Services

The table lists platform endpoints configured in Git; test live availability separately.

| Service | URL | Description |
|---|---|---|
| ArgoCD | `https://argocd.homelab.local` | GitOps dashboard — sync status for all apps |
| Grafana | `https://grafana.homelab.local` | Metrics and log dashboards |
| Prometheus | `https://prometheus.homelab.local` | Metrics query interface |
| Alertmanager | `https://alertmanager.homelab.local` | Alert management |
| Gitea | `https://gitea.homelab.local` | Self-hosted Git server |

---

## 🤖 AI Integration

Phase 7 explored a local AI layer. Ollama remains outside Kubernetes; the Open WebUI,
k8sgpt, and AI Gateway cluster deployments were later retired.

**Core principle:** AI may generate intent, but reviewed GitOps changes execute it.

The previous AI Gateway usage example is historical, not a live endpoint. See
[ADR-005](docs/adr/005-ai-integration-strategy.md) for the original design and its
retirement note. Verify the current Ollama model inventory on the NUC before naming
loaded models.

---

## ✅ Build Phases (historical milestones, not current deployment inventory)

| Phase | Focus | Status |
|---|---|---|
| **1 — Foundations** | Proxmox, Terraform VMs, Ansible k3s bootstrap, Pi-hole DNS | ✅ Complete |
| **2 — GitOps** | k3s cluster, ArgoCD App-of-Apps, Traefik, MetalLB | ✅ Complete |
| **3 — Certificates** | cert-manager, private CA, HTTPS for all services | ✅ Complete |
| **4 — CI/CD** | GitHub Actions, GHCR, GitOps manifest update loop | ✅ Complete |
| **5 — Observability** | kube-prometheus-stack, Loki, Grafana dashboards | ✅ Complete |
| **6 — Self-hosted Git** | Gitea server, formerly Gitea runner, GitHub mirror | ✅ Milestone; runner retired |
| **7 — AI Integration** | Ollama; former Open WebUI, k8sgpt, AI Gateway API | ✅ Milestone; k3s consumers retired |

---

## 📖 Architecture Decision Records

Key decisions are documented as [Architecture Decision Records](docs/adr/) — short
documents explaining *why* a particular approach was chosen, what alternatives were
considered, and what trade-offs were accepted.

| ADR | Decision |
|---|---|
| [ADR-001](docs/adr/001-monorepo.md) | Mono-repo structure over multi-repo |
| [ADR-002](docs/adr/002-k3s-over-kubeadm.md) | k3s over kubeadm for cluster bootstrapping |
| [ADR-003](docs/adr/003-certificate-strategy.md) | Private CA over Let's Encrypt for internal services |
| [ADR-004](docs/adr/004-gitea-self-hosted-git.md) | Self-hosted Gitea as internal Git mirror |
| [ADR-005](docs/adr/005-ai-integration-strategy.md) | AI integration architecture — local inference, GitOps-first |
| [ADR-006](docs/adr/006-cicd-pipeline.md) | GitHub Actions over Gitea Actions, GHCR over Harbor |
| [ADR-007](docs/adr/007-observability.md) | kube-prometheus-stack, Loki, unified Grafana |
| [ADR-008](docs/adr/008-single-server-pi-workers.md) | One k3s server VM with three Raspberry Pi workers |

---

## 📝 Notes

This is a living project built in parallel with studying for platform engineering roles
in Switzerland. Every component serves a deliberate purpose — tools are not added for their
own sake.

Demo workloads retired from Kubernetes can still have source code and CI workflows in
the repository. In particular, the retained `ai-gateway` and `hello-platform` workflows
reference deployment YAML paths removed by the retirement PR; do not treat a source
build as a working deployment or modify protected workflows as part of housekeeping.