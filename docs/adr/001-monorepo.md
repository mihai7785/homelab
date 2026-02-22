# ADR-001: Mono-repo Structure

**Date:** 2025-02  
**Status:** Accepted

## Context

When starting the homelab platform project, a decision was needed on how to organize code across Git repositories. The two main options considered were:

**Option A — Mono-repo:** All infrastructure, GitOps manifests, platform config, and application code in a single repository with subdirectories per concern.

**Option B — Multi-repo:** Separate repositories per concern (e.g. `homelab-infra`, `homelab-gitops`, `homelab-apps`, etc.), mirroring how larger organizations often structure things.

## Decision

Mono-repo (Option A), with directory structure designed to allow future splitting.

## Rationale

1. **Single person, single context.** With one contributor, the main benefit of multi-repo (independent access control, independent pipelines per team) does not apply. The overhead of managing cross-repo dependencies and keeping a mental map of 8 half-empty repos outweighs the benefits at this stage.

2. **Easier onboarding.** When sharing the portfolio with potential employers, a single well-structured repo communicates the full picture immediately. A visitor can understand the entire platform by reading one README.

3. **Future-proof structure.** Each subdirectory (`infra/`, `gitops/`, `platform/`, `apps/`) is self-contained and can be extracted into its own repo later without major rework. ArgoCD and AWX both support watching specific subdirectory paths within a repo, so no tooling changes would be required.

4. **Consistent history.** Cross-cutting changes (e.g. adding a new cluster node that requires Terraform code, an Ansible playbook, and an ArgoCD app manifest) are expressed in a single commit, making history easier to follow.

## Consequences

- All CI/CD pipelines in this repo must be path-filtered to avoid triggering on unrelated changes.
- As the `apps/` directory grows, it may be split into per-app repos. This will be revisited when there are more than 3 applications.
- GitHub Actions / Gitea Actions workflows use `paths:` filters to scope triggers correctly.
