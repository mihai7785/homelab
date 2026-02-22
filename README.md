# 🏠 Homelab — Internal Developer Platform

A self-hosted Internal Developer Platform (IDP) built on Kubernetes, following GitOps principles.
This homelab serves as both a learning environment and a portfolio demonstrating real-world platform engineering practices.

> **Status:** 🚧 Actively being built — see [build phases](#build-phases) for current progress.

---

## 📐 Architecture Overview

```
┌─────────────────────────────────────────────────────────────────────┐
│                         GitHub (Public Mirror)                       │
│              Source of truth for all infrastructure & apps           │
└────────────────────────────┬────────────────────────────────────────┘
                             │ push / webhook
                             ▼
┌─────────────────────────────────────────────────────────────────────┐
│                     Gitea  (Self-hosted Git)                         │
│              Internal mirror · CI pipelines via Gitea Actions        │
└──────────┬──────────────────────────────────────────────────────────┘
           │ build → push image          │ update image tag in gitops
           ▼                             ▼
┌─────────────────┐          ┌──────────────────────────────────────┐
│  Harbor          │          │         k3s Cluster (3 nodes)        │
│  Container       │          │                                      │
│  Registry        │◄─────────│  ArgoCD · Traefik · cert-manager    │
│  (image scan +   │  pull    │  Prometheus · Grafana · Loki         │
│   replication)   │          │  Gitea · Harbor · Your Apps          │
└─────────────────┘          └──────────────┬───────────────────────┘
                                            │
                    ┌───────────────────────┼───────────────────────┐
                    ▼                       ▼                       ▼
         ┌─────────────────┐    ┌─────────────────┐    ┌──────────────────┐
         │  Synology NAS   │    │   AWX + Ansible  │    │  NUC14+ (AI)     │
         │  - Longhorn bkp │    │  - IaC triggers  │    │  - Ollama        │
         │  - MinIO S3     │    │  - provisioning  │    │  - RTX 4080      │
         │  - PBS target   │    │  - wired to GH   │    │  - FastAPI GW    │
         └─────────────────┘    └─────────────────┘    └──────────────────┘
```

---

## 🖥️ Hardware

| Device | Role | Specs |
|---|---|---|
| HP Mini PC (main Proxmox) | Hypervisor — hosts all platform VMs | 28 vCPU · 31GB RAM |
| Asus Mini PC (secondary Proxmox) | Home Assistant + auxiliary VMs | 4 vCPU · 16GB RAM |
| Synology DS1525+ | NAS — backups, S3, persistent storage | 7TB |
| Asus NUC14+ (daily driver) | AI workloads — Ollama + RTX 4080 | 96GB RAM · RTX 4080 eGPU |
| 3× Raspberry Pi 4B | Reserved — future worker nodes | 4GB RAM each |

---

## 🗂️ Repository Structure

```
homelab/
├── infra/
│   ├── terraform/        # Proxmox VM provisioning
│   └── ansible/          # OS config, k3s bootstrap, service config
├── gitops/
│   ├── core/             # Bootstrap: ArgoCD, cert-manager, ingress
│   ├── apps/             # ArgoCD Application manifests (App-of-Apps)
│   └── projects/         # ArgoCD Project definitions
├── platform/
│   ├── charts/           # Custom Helm charts
│   └── values/           # Per-environment Helm values
├── apps/
│   └── hello-platform/   # Sample app — FastAPI, Dockerfile, Helm chart, CI
├── monitoring/
│   ├── dashboards/       # Grafana dashboard JSON
│   └── alerts/           # Prometheus alerting rules
└── docs/
    ├── architecture.md
    └── adr/              # Architecture Decision Records
```

---

## ⚙️ Technology Stack

### Infrastructure & Provisioning
| Tool | Purpose |
|---|---|
| **Proxmox VE** | Hypervisor — runs all VMs and LXC containers |
| **Terraform** | VM provisioning via Proxmox provider |
| **Ansible** | OS configuration, k3s bootstrap, service management |
| **AWX** | Ansible control plane — UI + scheduling for playbook execution |

### Kubernetes Platform
| Tool | Purpose |
|---|---|
| **k3s** | Lightweight Kubernetes distribution — 3-node cluster |
| **Helm** | Kubernetes package manager — deploy and manage applications |
| **Traefik** | Ingress controller — routes external traffic to cluster services |
| **Longhorn** | Distributed block storage — persistent volumes for stateful apps |

### GitOps & CI/CD
| Tool | Purpose |
|---|---|
| **ArgoCD** | GitOps continuous delivery — reconciles cluster state from Git |
| **Gitea** | Self-hosted Git server — internal source of truth |
| **Gitea Actions** | CI pipelines — build, test, push images on every commit |
| **Harbor** | Container registry — image storage, scanning, and replication |

### Observability
| Tool | Purpose |
|---|---|
| **Prometheus** | Metrics collection and alerting |
| **Grafana** | Dashboards — unified view of metrics and logs |
| **Loki** | Log aggregation — ships logs from all pods |
| **Promtail** | Log collection agent — runs on every node |
| **Alertmanager** | Alert routing — sends to Telegram / Discord |

### Security & Certificates
| Tool | Purpose |
|---|---|
| **cert-manager** | Automatic certificate issuance and renewal in Kubernetes |
| **step-ca** | Internal Certificate Authority — signs certs for `*.homelab.local` |
| **Let's Encrypt** | Public CA — real certs via DNS-01 challenge (no open ports) |
| **Vaultwarden** | Self-hosted Bitwarden — secrets and password management |

### AI
| Tool | Purpose |
|---|---|
| **Ollama** | Local LLM runtime — runs on NUC14+ with RTX 4080 |
| **Open WebUI** | Chat interface — deployed in cluster, calls Ollama API |
| **FastAPI AI Gateway** | Python wrapper — OpenAI-compatible API over Ollama |

---

## 🚀 Build Phases

| Phase | Focus | Status |
|---|---|---|
| **0 — Foundations** | GitHub structure, Proxmox VMs, DNS via Pi-hole | ✅ In progress |
| **1 — IaC** | Terraform for VMs, Ansible playbooks, AWX wiring | 🔜 Next |
| **2 — K8s + GitOps** | k3s cluster, ArgoCD, Gitea, Harbor, first GitOps loop | ⬜ Planned |
| **3 — CI/CD** | Gitea Actions pipeline: push → build → deploy | ⬜ Planned |
| **4 — Certificates** | step-ca internal PKI, cert-manager, HTTPS everywhere | ⬜ Planned |
| **5 — Observability** | Prometheus, Grafana, Loki, Alertmanager, custom dashboards | ⬜ Planned |
| **6 — AI** | Ollama, alert enricher, Open WebUI, Backstage portal | ⬜ Planned |

---

## 📖 Architecture Decisions

Key decisions are documented as [Architecture Decision Records](docs/adr/) — short documents explaining *why* a particular approach was chosen, not just what was implemented.

- [ADR-001](docs/adr/001-monorepo.md) — Mono-repo structure
- [ADR-002](docs/adr/002-k3s-over-kubeadm.md) — k3s over kubeadm
- [ADR-003](docs/adr/003-certificate-strategy.md) — Certificate management strategy

---

## 🔗 Related

- [AWX Ansible Playbooks](https://github.com/mihai7785) — Ansible content used by AWX
- [Proxmox Backup Server](infra/terraform/) — PBS config targeting Synology NAS

---

## 📝 Notes

This is a living project. Architecture decisions are made deliberately and documented. Every tool in this stack serves a specific purpose — I avoid adding technology for its own sake.

All services run on self-hosted infrastructure with no dependency on cloud providers.
