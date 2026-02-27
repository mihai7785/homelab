# ADR-006: CI/CD Pipeline Strategy

**Date:** 2026-02
**Status:** Accepted

## Context

Phase 4 required a CI/CD pipeline to automate the build and deployment of containerised
applications. The goal was to establish a complete developer loop: code push → image build
→ registry push → GitOps manifest update → ArgoCD deployment, targeting a cycle time
under 5 minutes.

Three decisions were made in this phase: the CI runner platform, the container registry,
and the GitOps update mechanism.

## Decisions

### 1. GitHub Actions over Gitea Actions

The initial plan was to run CI pipelines on Gitea Actions, using a self-hosted runner
deployed in k3s (the `gitea-runner` ArgoCD application). This would keep the entire CI
loop self-hosted.

**Why we pivoted to GitHub Actions:**

Gitea Actions uses the same YAML syntax as GitHub Actions but has subtle compatibility
gaps. The `docker/build-push-action` and `docker/metadata-action` marketplace actions
failed to run correctly on the self-hosted Gitea runner due to missing environment
variables that GitHub Actions injects automatically. Debugging these gaps consumed
significant time without progress.

**Decision:** Use GitHub Actions with the hosted `ubuntu-latest` runner for CI. The
self-hosted Gitea runner remains deployed and available for future migration once the
foundational pipeline patterns are stable.

**Rationale:**
1. **Unblocking progress.** A working CI pipeline in 30 minutes on GitHub Actions is
   more valuable than a partially working one on Gitea Actions after several days of
   debugging.
2. **Same YAML, different runner.** Migrating back to Gitea Actions later requires
   only changing `runs-on: ubuntu-latest` to `runs-on: gitea-runner` and resolving
   any remaining compatibility issues. The pipeline logic is identical.
3. **GitHub Actions ecosystem.** The marketplace actions (`docker/build-push-action`,
   `docker/metadata-action`, `actions/checkout`) are battle-tested on GitHub's hosted
   runners. Using them correctly is more valuable learning than debugging runner
   compatibility issues.

### 2. GitHub Container Registry (GHCR) over Harbor

The original plan included a self-hosted Harbor registry for image storage and scanning.

**Decision:** Use GitHub Container Registry (GHCR) as the primary container registry.

**Rationale:**
1. **Native integration with GitHub Actions.** GHCR is authenticated automatically via
   `${{ secrets.GITHUB_TOKEN }}` in GitHub Actions workflows — no additional secrets
   or registry configuration required.
2. **Reduced operational overhead.** Harbor requires its own database, Redis, and
   persistent storage. For a homelab with one active application, this overhead is
   disproportionate to the value.
3. **Public visibility.** Images pushed to GHCR under a public repository are publicly
   visible, which supports the portfolio goal — interviewers can see the built images.
4. **Future Harbor path.** Harbor remains a planned addition for Phase 8+ when image
   scanning, replication policies, and pull-through caching become relevant.

### 3. GitOps Manifest Update via `sed` in CI

After pushing an image, the CI pipeline must update the image tag in the GitOps
manifest so ArgoCD deploys the new version. Two approaches were considered:

**Option A:** CI updates the manifest file directly (sed replacement) and commits to main.

**Option B:** Use a dedicated tool like `kustomize edit set image` or `flux image
automation`.

**Decision:** Option A — direct `sed` replacement in the CI workflow, committing
back to `main`.

**Rationale:**
1. **Simplicity.** A four-line shell script is immediately understandable. It introduces
   no new tools and has no failure modes beyond git push permission.
2. **Explicit.** The exact change the CI makes is visible in the Git history as a
   separate commit with a clear message (`chore: update <app> image to <sha>`).
3. **Scale.** For a homelab with a small number of applications, the pattern is
   entirely adequate. kustomize image automation would be appropriate at 20+ apps.

## Consequences

- GitHub-hosted runners are used for CI, incurring GitHub Actions free tier minutes.
  At current usage (one application, infrequent pushes) this stays well within the
  2,000 free minutes/month.
- Images are stored on GHCR rather than a self-hosted registry. There is a dependency
  on GitHub's availability for new deployments (existing deployed images are unaffected).
- The self-hosted Gitea runner is deployed but unused. It should be migrated to as a
  future improvement once GitHub Actions compatibility is confirmed.
- The `sed`-based manifest update requires the deployment YAML to contain exactly one
  matching image line. This is enforced by convention in `gitops/apps/<app>/deployment.yaml`.