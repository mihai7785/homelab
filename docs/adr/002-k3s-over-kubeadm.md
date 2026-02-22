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

4. **ARM64 support.** When Raspberry Pi 4B nodes are added in a later phase, k3s supports ARM64 natively without additional configuration. kubeadm would require more manual work for a mixed x86/ARM64 cluster.

5. **Existing familiarity.** The `k3s-core` VM already runs k3s. Operational knowledge transfers directly.

## Consequences

- Some kubeadm-specific knowledge (e.g. `kubeadm init` flags, certificate management via kubeadm) will not be gained from this setup. This is acceptable — kubeadm knowledge is less relevant for platform engineering roles than cluster operations and GitOps.
- k3s uses `containerd` as the container runtime (no Docker). This is the correct and modern approach — Docker as a Kubernetes runtime is deprecated.
- Traefik is used as the ingress controller (comes with k3s). Nginx Ingress is more common in enterprise environments, but Traefik is a valid and growing choice and the concepts are transferable.
