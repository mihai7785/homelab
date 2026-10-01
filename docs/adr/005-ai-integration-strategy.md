# ADR-005: AI Integration Strategy

**Date:** 2026-02
**Status:** Accepted as a historical design; k3s consumers retired (2026-10-01)

## Context

Phase 7 of the homelab IDP introduced AI capabilities. Several architectural decisions
were required around where to run inference, how to expose it to the cluster, which
interface to provide, and how AI-generated output should interact with existing GitOps
workflows.

The available hardware includes an Asus NUC14+ with 96GB RAM and an NVIDIA RTX 4080
Super (16GB VRAM) connected via Thunderbolt as an eGPU, running Windows 11. The k3s
server runs on Proxmox VM 301, with three Raspberry Pi workers; none has this GPU.

The long-term vision extends beyond platform tooling: the same AI infrastructure should
eventually serve Home Assistant voice automation, smart home habit learning, and a
network-aware assistant ("Jarvis-like") that monitors both the homelab and home network.
This broader scope influenced several decisions.

## Decisions

**Deployment update (2026-10-01):** Ollama remains outside k3s. Open WebUI, k8sgpt,
and the AI Gateway were retired from the cluster. The decisions below preserve the
original Phase 7 reasoning and do not describe active Kubernetes services. The
AI Gateway source code remains in `apps/`; its GitOps deployment does not.

### 1. Ollama on bare metal (Windows), not in k3s

Ollama runs natively on the NUC14+ Windows 11 host rather than as a container in k3s,
listening on `0.0.0.0:11434` and accessible to all network clients.

**Alternatives considered:**
- Run Ollama in k3s with GPU passthrough via device plugin — rejected because the GPU
  is on a separate physical host (the NUC), not on any k3s node. GPU passthrough into
  k3s would require running k3s on the NUC itself, which conflicts with its role as a
  daily driver and Home Assistant integration host.
- Run Ollama in WSL2 — rejected because native Windows provides simpler GPU access
  without Thunderbolt eGPU compatibility concerns in the WSL2 kernel.

**Rationale:** The NUC is the right host for AI workloads by hardware design. Bare metal
Windows gives direct CUDA access to the eGPU with no virtualization overhead. The
`0.0.0.0` binding makes Ollama a network-accessible inference endpoint, usable by any
system on the homelab network — k3s services, Home Assistant, and future agents alike.

### 2. Ollama as the central AI hub

Rather than deploying separate AI backends per use case, the design placed Ollama on a
single host for the former Open WebUI, k8sgpt and AI Gateway consumers and potential
future Home Assistant integration. Those three cluster consumers are no longer deployed.

**Rationale:** This mirrors the microservices pattern of a shared platform service with
multiple consumers. It centralizes model management (pull once, use everywhere), simplifies
monitoring (one endpoint to observe), and avoids running duplicate model weights in memory.
With 96GB RAM and 16GB VRAM, the NUC has capacity for multiple concurrent model loads.

### 3. Open WebUI in k3s (retired)

The chat interface formerly ran as a StatefulSet in k3s (namespace: `open-webui`) rather than
locally on the NUC, with HTTPS ingress at `openwebui.homelab.local`.

**Rationale:** Keeping the UI in k3s maintains the principle that user-facing services
belong to the platform. It benefits from the existing ingress, TLS, NFS persistence, and
ArgoCD lifecycle management. Open WebUI also provides a foundation for future RAG
(retrieval-augmented generation) workflows and multi-user access.

### 4. k8sgpt for AI-powered cluster diagnostics (retired)

k8sgpt-operator was deployed in k3s with Ollama as the AI backend. It analyzed
cluster resources and stored findings as Kubernetes CRDs (`Result` objects),
with a ServiceMonitor exposing metrics to Prometheus. It is not deployed now.

**Alternatives considered:**
- Cloud-backed k8sgpt (OpenAI, Azure OpenAI) — rejected to avoid sending cluster state
  data to external services and to avoid ongoing API costs.
- Manual log analysis — replaced by automated analysis, which is more consistent and
  scales with cluster growth.

**Rationale:** k8sgpt demonstrates the Kubernetes operator pattern in the portfolio —
a controller that watches cluster state and reconciles against a desired state (healthy,
explainable resources). The local Ollama backend keeps cluster diagnostics data entirely
on-premises.

### 5. "AI generates intent, humans or GitOps execute it"

AI is an input layer to existing workflows, not a bypass of them. The AI Gateway (Phase
7 continuation) was designed to generate Kubernetes manifests or Terraform code from
natural language requests and submit changes via Pull Request rather than applying them
directly to the cluster. Its Kubernetes deployment has been retired.

**Rationale:** This mirrors responsible AI integration patterns in production platform
teams. Maintaining human review (PR approval) and existing automation (ArgoCD sync)
as the execution layer ensures auditability, rollback capability, and alignment with
GitOps principles. AI accelerates intent expression; it does not replace governance.

## Models

| Model | Purpose | Size | Backend |
|---|---|---|---|
| `llama3.1:8b` | General chat, prospective Home Assistant use, former k8sgpt analysis | 4.9GB | Ollama |
| `qwen2.5-coder:7b` | K8s manifest and Terraform generation | 4.7GB | Ollama |

At design time, both models were expected to fit in the RTX 4080's 16GB VRAM. The
Thunderbolt eGPU can also use shared GPU memory backed by system RAM. This is a
historical model selection, not a live inventory of loaded Ollama models.

## Consequences

- Ollama is a non-Kubernetes dependency. When the former cluster consumers were
  deployed, an unavailable NUC removed their AI capability. Those consumers are
  retired; any future consumer will still depend on the NUC unless redesigned.
- Windows 11 on the NUC requires manual Ollama service management (restart on reboot,
  environment variable persistence). A future improvement would be configuring Ollama
  as a proper Windows Service with automatic startup.
- The `OLLAMA_HOST=0.0.0.0:11434` binding exposes the inference API to the entire LAN
  with no authentication. Acceptable within a trusted home network; not acceptable in
  production without an API gateway or mTLS.
- Home Assistant Ollama integration is straightforward via the official HA integration,
  pointing to `http://192.168.1.94:11434`. This is deferred to a future phase but
  requires no architectural changes to what is built here.
