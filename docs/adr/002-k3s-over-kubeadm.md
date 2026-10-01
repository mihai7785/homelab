# ADR-002: k3s Over kubeadm

**Date:** 2025-02  
**Status:** Accepted

## Context

A Kubernetes distribution had to be chosen for the homelab cluster. The main candidates were:

- **kubeadm** — the standard upstream tool for bootstrapping Kubernetes clusters
- **k3s** — a CNCF-certified, production-grade lightweight Kubernetes distribution by Rancher/SUSE
- **kind / minikube** — local development clusters, not suitable for persistent homelab use

An existing single-node k3s cluster (`k3s-core`) is already in use for CKAD exam preparation, so there is existing familiarity with k3s.

## Decision

k3s for the homelab platform cluster.

## Rationale

1. **Resource efficiency.** k3s uses significantly less memory than a full kubeadm cluster. The control plane node runs comfortably in 2GB RAM vs. ~4GB+ for kubeadm. This matters on Proxmox where RAM is a shared resource.

2. **Production-grade.** k3s is CNCF certified and used in production by companies including Rancher, SUSE, and many edge/IoT deployments. Skills transfer directly to real-world environments.

3. **Built-in components.** k3s ships with Traefik (ingress), local-path-provisioner (basic storage), CoreDNS, and metrics-server by default. This reduces bootstrap complexity.

4. **ARM64 support.** The three Raspberry Pi workers now run ARM64 alongside the amd64 server VM. k3s supports this mixed-architecture cluster; images without ARM64 support must be pinned to amd64.

5. **Existing familiarity.** The `k3s-core` VM already runs k3s. Operational knowledge transfers directly.

## Consequences

- Some kubeadm-specific knowledge (e.g. `kubeadm init` flags, certificate management via kubeadm) will not be gained from this setup. This is acceptable — kubeadm knowledge is less relevant for platform engineering roles than cluster operations and GitOps.
- k3s uses `containerd` as the container runtime (no Docker). This is the correct and modern approach — Docker as a Kubernetes runtime is deprecated.
- Traefik is used as the ingress controller (comes with k3s). Nginx Ingress is more common in enterprise environments, but Traefik is a valid and growing choice and the concepts are transferable.

## Current topology (2026-10-01)

One Proxmox VM (`k3s-server-01`, VM 301) runs the k3s server; `raspberry-agentic-main`, `raspberry-agentic-slave1`, and `raspberry-agentic-slave2` are the workers. The former worker VMs 302 and 303 are retired. See [ADR-008](008-single-server-pi-workers.md) for the topology decision and failure-domain trade-off.
