# 🏠 Homelab — Internal Developer Platform

A self-hosted Internal Developer Platform (IDP) built on Kubernetes, following GitOps
principles. This homelab serves as both a learning environment and a portfolio
demonstrating real-world platform engineering practices.

> **Status:** ✅ All 7 phases complete — platform fully operational.

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
│  GitHub Actions  │              │        k3s Cluster (3 nodes)    │
│  Build & push   │──────────────►│                                 │
│  image to GHCR  │  image tag   │  ArgoCD · Traefik · cert-manager│
└─────────────────┘  update PR   │  Prometheus · Grafana · Loki    │
                                 │  Gitea · AI Gateway · k8sgpt    │
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

**AI Gateway flow:**
```
Natural language → AI Gateway API → Ollama (local GPU) → K8s manifest
                                                               │
                                                        GitHub Pull Request
                                                               │
                                                     Human review & merge
                                                               │
                                                    ArgoCD detects & deploys
```

---

## 🖥️ Hardware

| Device | Role | Specs |
|---|---|---|
| HP Mini PC | Primary Proxmox hypervisor — hosts all platform VMs | 28 vCPU · 31GB RAM |
| Asus Mini PC | Secondary Proxmox — Home Assistant + auxiliary VMs | 4 vCPU · 16GB RAM |
| Synology DS1525+ | NAS — NFS persistent storage for k3s PVCs | 7TB usable |
| Asus NUC14+ | AI workloads — Ollama with RTX 4080 Super eGPU | 96GB RAM · 16GB VRAM |
| Raspberry Pi 4B ×3 | Reserved for future worker node expansion | 4GB RAM each |

**k3s cluster nodes (Proxmox VMs on HP Mini PC):**

| Node | Role | vCPU | RAM |
|---|---|---|---|
| k3s-server-01 | Control plane + worker | 4 | 8GB |
| k3s-worker-01 | Worker | 4 | 8GB |
| k3s-worker-02 | Worker | 4 | 8GB |

---

## 🗂️ Repository Structure

```
homelab/
├── apps/
│   ├── hello-platform/     # Reference FastAPI app — Dockerfile, CI pipeline
│   └── ai-gateway/         # AI Gateway API — natural language → K8s manifests
├── gitops/
│   └── apps/               # ArgoCD Application manifests (App-of-Apps pattern)
│       ├── ai-generated/   # Landing zone for AI Gateway generated manifests
│       └── */              # One directory per deployed application
├── infrastructure/
│   └── k8sgpt/             # k8sgpt custom resource definition
├── monitoring/
│   └── dashboards/         # Grafana dashboard JSON exports
├── platform/
│   └── values/             # Helm values files for all platform components
└── docs/
    └── adr/                # Architecture Decision Records (001–007)
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
| **k3s** | Lightweight Kubernetes — 3-node cluster (1 control plane, 2 workers) |
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
| **Open WebUI** | Chat interface — deployed in k3s, connects to Ollama |
| **k8sgpt** | AI cluster diagnostics — explains issues via Ollama, stores as CRDs |
| **AI Gateway** | FastAPI service — natural language → K8s manifest → GitHub PR |

---

## 🚀 Platform Services

All services run on `*.homelab.local` with valid TLS certificates (green padlock).

| Service | URL | Description |
|---|---|---|
| ArgoCD | `https://argocd.homelab.local` | GitOps dashboard — sync status for all apps |
| Grafana | `https://grafana.homelab.local` | Metrics and log dashboards |
| Prometheus | `https://prometheus.homelab.local` | Metrics query interface |
| Alertmanager | `https://alertmanager.homelab.local` | Alert management |
| Gitea | `https://gitea.homelab.local` | Self-hosted Git server |
| Open WebUI | `https://openwebui.homelab.local` | Local AI chat interface |
| AI Gateway | `https://ai-gateway.homelab.local` | Natural language → manifest API |
| AI Gateway Docs | `https://ai-gateway.homelab.local/docs` | Interactive Swagger UI |

---

## 🤖 AI Integration

Phase 7 added a local AI layer that maintains the GitOps workflow rather than bypassing it.

**Core principle:** AI generates intent, humans or GitOps execute it. No AI component
has direct cluster access.

### AI Gateway — Usage Example

```bash
# Generate a Kubernetes manifest from natural language
curl -k -X POST https://ai-gateway.homelab.local/generate/manifest \
  -H "Content-Type: application/json" \
  -d '{
    "prompt": "deploy nginx with 2 replicas and expose it on port 80",
    "app_name": "nginx-demo"
  }'

# Returns:
# {
#   "pr_url": "https://github.com/mihai7785/homelab/pull/N",
#   "branch": "ai-gateway/nginx-demo-abc123",
#   "manifest": "apiVersion: apps/v1\nkind: Deployment...",
#   "app_name": "nginx-demo"
# }
```

The API opens a Pull Request with the generated manifest. A human reviews and merges.
ArgoCD detects the merged change and deploys to the `ai-generated` namespace.

### Models

| Model | Size | Use |
|---|---|---|
| `llama3.1:8b` | 4.9GB (Q4_K_M) | General chat, k8sgpt diagnostics, Home Assistant (future) |
| `qwen2.5-coder:7b` | 4.7GB (Q4_K_M) | K8s manifest and Terraform code generation |

Both models run simultaneously in the RTX 4080 Super's 16GB VRAM.

---

## ✅ Build Phases

| Phase | Focus | Status |
|---|---|---|
| **1 — Foundations** | Proxmox, Terraform VMs, Ansible k3s bootstrap, Pi-hole DNS | ✅ Complete |
| **2 — GitOps** | k3s cluster, ArgoCD App-of-Apps, Traefik, MetalLB | ✅ Complete |
| **3 — Certificates** | cert-manager, private CA, HTTPS for all services | ✅ Complete |
| **4 — CI/CD** | GitHub Actions, GHCR, GitOps manifest update loop | ✅ Complete |
| **5 — Observability** | kube-prometheus-stack, Loki, Grafana dashboards | ✅ Complete |
| **6 — Self-hosted Git** | Gitea server, Gitea runner, GitHub mirror | ✅ Complete |
| **7 — AI Integration** | Ollama, Open WebUI, k8sgpt, AI Gateway API | ✅ Complete |

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

---

## 📝 Notes

This is a living project built in parallel with studying for platform engineering roles
in Belgium. Every component serves a deliberate purpose — tools are not added for their
own sake.

The AI Gateway is the centrepiece of Phase 7: it demonstrates responsible AI integration
in a platform engineering context — AI as an accelerator for the authoring step, with the
existing GitOps review and deployment process fully preserved.