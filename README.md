# 🏠 Homelab — Internal Developer Platform

A self-hosted Internal Developer Platform (IDP) built on Kubernetes, following GitOps principles.
This homelab serves as both a learning environment and a portfolio demonstrating real-world platform engineering practices.

> **Status:** 🚧 Actively being built — see [build phases](#-build-phases) for current progress.

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
         │  - NFS storage  │    │  - IaC triggers  │    │  - Ollama        │
         │  - PBS target   │    │  - provisioning  │    │  - RTX 4080      │
         └─────────────────┘    └─────────────────┘    └──────────────────┘
```

---

## 🖥️ Hardware

| Device | Role | Specs |
|---|---|---|
| HP Mini PC (main Proxmox) | Hypervisor — hosts all platform VMs | 28 vCPU · 31GB RAM |
| Asus Mini PC (secondary Proxmox) | Home Assistant + auxiliary VMs | 4 vCPU · 16GB RAM |
| Synology DS1525+ | NAS — NFS persistent storage, PBS backup target | 2× 8TB HDD · 1TB NVMe SSD |
| Asus NUC14+ (daily driver) | AI workloads — Ollama + RTX 4080 | 96GB RAM · RTX 4080 eGPU |
| 3× Raspberry Pi 4B | Reserved — future worker nodes | 4GB RAM each |

---

## 🗂️ Repository Structure
```
homelab/
├── infrastructure/
│   ├── terraform/          # Proxmox VM provisioning
│   ├── ansible/            # OS hardening, k3s bootstrap
│   ├── argocd/             # ArgoCD Helm values
│   ├── cert-manager/       # cert-manager values + ClusterIssuer
│   ├── gitea/              # Gitea Helm values + Traefik IngressRoute
│   ├── metallb/            # MetalLB values + IP pool config
│   ├── nfs-provisioner/    # NFS subdir provisioner values
│   └── traefik/            # Traefik values + dashboard + middleware
├── gitops/
│   ├── apps/               # ArgoCD Application manifests (App-of-Apps)
│   ├── core/               # Bootstrap manifests
│   └── projects/           # ArgoCD Project definitions
├── apps/
│   └── hello-platform/     # Sample app — FastAPI, Dockerfile, Helm chart
├── monitoring/
│   ├── dashboards/         # Grafana dashboard JSON
│   └── alerts/             # Prometheus alerting rules
├── platform/
│   ├── charts/             # Custom Helm charts
│   └── values/             # Per-environment Helm values
└── docs/
    └── adr/                # Architecture Decision Records
```

---

## ⚙️ Technology Stack

### Infrastructure & Provisioning
| Tool | Purpose |
|---|---|
| **Proxmox VE** | Hypervisor — runs all VMs and LXC containers |
| **Terraform** | VM provisioning via Proxmox provider |
| **Ansible** | OS hardening, k3s bootstrap, cluster configuration |

### Kubernetes Platform
| Tool | Purpose |
|---|---|
| **k3s** | Lightweight Kubernetes — 3-node cluster (1 server, 2 workers) |
| **Helm** | Kubernetes package manager |
| **Traefik** | Ingress controller — HTTPS routing with HTTP→HTTPS redirect |
| **MetalLB** | Bare-metal load balancer — exposes services on LAN IPs |
| **NFS subdir provisioner** | Dynamic PV provisioning backed by Synology NAS SSD |

### GitOps & CI/CD
| Tool | Purpose |
|---|---|
| **ArgoCD** | GitOps engine — App-of-Apps pattern, self-managed |
| **Gitea** | Self-hosted Git — internal mirror, future CI source |
| **Gitea Actions** | CI pipelines — planned Phase 4 |
| **Harbor** | Container registry — planned Phase 5 |

### Security & Certificates
| Tool | Purpose |
|---|---|
| **cert-manager** | Automatic TLS certificate issuance and renewal |
| **Private CA** | Homelab root CA — signs `*.homelab.local` certificates |

### Observability *(planned)*
| Tool | Purpose |
|---|---|
| **Prometheus** | Metrics collection and alerting |
| **Grafana** | Dashboards and visualisation |
| **Loki + Promtail** | Log aggregation |
| **Alertmanager** | Alert routing |

### AI *(planned)*
| Tool | Purpose |
|---|---|
| **Ollama** | Local LLM runtime on NUC14+ with RTX 4080 |
| **Open WebUI** | Chat interface deployed in cluster |

---

## 🚀 Build Phases

| Phase | Focus | Status |
|---|---|---|
| **1 — IaC & Cluster** | Terraform VMs, Ansible hardening, k3s 3-node cluster | ✅ Complete |
| **2 — GitOps Foundation** | ArgoCD App-of-Apps, MetalLB, Traefik, cert-manager, private CA, HTTPS | ✅ Complete |
| **3 — Developer Platform** | NFS StorageClass (Synology SSD), Gitea with PostgreSQL, TLS, GitHub mirror | ✅ Complete |
| **4 — CI/CD Pipelines** | Gitea Actions, container builds, automated GitOps deployments | 🔜 Next |
| **5 — Observability** | Prometheus, Grafana, Loki, Alertmanager, custom dashboards | ⬜ Planned |
| **6 — AI Integration** | Ollama, Open WebUI, FastAPI AI Gateway | ⬜ Planned |

---

## 🌐 Running Services

| Service | URL | Description |
|---|---|---|
| **ArgoCD** | https://argocd.homelab.local | GitOps dashboard — manages all cluster apps |
| **Traefik** | https://traefik.homelab.local | Ingress controller dashboard |
| **Gitea** | https://gitea.homelab.local | Self-hosted Git server |

All services run over HTTPS with certificates issued by the homelab private CA.

---

## 📖 Architecture Decisions

| ADR | Decision |
|---|---|
| [ADR-001](docs/adr/001-monorepo.md) | Mono-repo structure |
| [ADR-002](docs/adr/002-k3s-over-kubeadm.md) | k3s over kubeadm |
| [ADR-003](docs/adr/003-certificate-strategy.md) | Certificate management strategy |
| [ADR-004](docs/adr/004-gitea-self-hosted-git.md) | Self-hosted Git with Gitea |

---

## 📝 Notes

This is a living project. Architecture decisions are made deliberately and documented. Every tool in this stack serves a specific purpose — technology is not added for its own sake.

All services run on self-hosted infrastructure with no dependency on cloud providers.
