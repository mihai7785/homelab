# ADR-004: Self-Hosted Git with Gitea

## Status
Accepted

## Context
The platform requires a Git server as the internal source of truth for application code and CI/CD pipelines. The initial setup uses GitHub as the GitOps source for ArgoCD, but a production-grade IDP should have an internal Git server for:
- CI/CD pipelines that don't depend on external services
- Complete control over the developer workflow
- Self-contained platform that works without internet access

## Decision
Deploy Gitea inside the k3s cluster, managed by ArgoCD, with PostgreSQL as the database backend and NFS-backed persistent storage on the Synology NAS.

## Alternatives Considered

**GitLab** — rejected due to very high resource consumption (4-8GB RAM minimum). Not suitable for a homelab cluster with constrained resources.

**Forgejo** — a Gitea fork, functionally identical. Gitea was chosen due to more mature Helm chart support and wider community adoption at this time.

**Gogs** — predecessor to Gitea, less actively maintained. Rejected in favour of Gitea.

**GitHub (external)** — keeping GitHub as the only Git server means CI/CD pipelines depend on an external service and cannot run fully self-hosted.

## Storage Decision
PostgreSQL and Gitea data are stored on NFS PersistentVolumes backed by the Synology DS1525+ SSD volume (Volume 2, 839GB free). This decouples data from compute — Gitea data survives VM rebuilds, cluster teardowns, and node failures. The `nfs-ssd` StorageClass uses `ReclaimPolicy: Retain` to prevent accidental data loss.

## Consequences
- Gitea is now the internal mirror of the GitHub homelab repo
- Future phases will configure ArgoCD to watch Gitea instead of GitHub, closing the self-hosted GitOps loop
- Gitea Actions (Phase 4) will provide CI pipelines without external dependencies
- All platform services now follow the same deployment pattern: Helm chart + ArgoCD Application + cert-manager Certificate + Traefik IngressRoute
