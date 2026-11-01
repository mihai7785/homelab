# Marketing agent: gated rollout (not deployment authorization)

This PR is **draft and must not merge yet**. `:pending-build` in the Deployment intentionally points to no image; replace it by `ghcr.io/mihai7785/marketing-agent@sha256:<actual GHCR digest>` in a reviewed PR after the image is built and its amd64 manifest is checked. No workflow is changed by Hermes. Mihai owns `.github/workflows/`.

## Workflow for Mihai to add

Copy the following complete YAML into `.github/workflows/marketing-agent-ci.yaml` yourself. It is intentionally *not* in that directory in this PR. It builds only when manually dispatched on the reviewed `agent/marketing-agent-isolation` branch, pushes an immutable SHA tag, reports a registry digest and never commits to `main` or edits GitOps. The repository's `packages: write` permission must be available to GitHub Actions; no personal token is needed.

```yaml
name: marketing-agent image
on:
  workflow_dispatch:
permissions:
  contents: read
  packages: write
jobs:
  build-amd64:
    if: startsWith(github.ref, 'refs/heads/agent/')
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: docker/setup-buildx-action@v3
      - uses: docker/login-action@v3
        with:
          registry: ghcr.io
          username: ${{ github.actor }}
          password: ${{ secrets.GITHUB_TOKEN }}
      - id: build
        uses: docker/build-push-action@v6
        with:
          context: apps/marketing-agent
          platforms: linux/amd64
          push: true
          tags: ghcr.io/${{ github.repository_owner }}/marketing-agent:sha-${{ github.sha }}
      - name: Report immutable reference
        env:
          DIGEST: ${{ steps.build.outputs.digest }}
        run: |
          test -n "$DIGEST"
          echo "Image: ghcr.io/${{ github.repository_owner }}/marketing-agent@$DIGEST" >> "$GITHUB_STEP_SUMMARY"
```

Run it on this PR's current head (e.g. `gh workflow run marketing-agent-ci.yaml --ref agent/marketing-agent-isolation`), verify the job, digest and architecture, then replace `:pending-build` by the reported digest via a new commit on this branch. **Do not merge while the placeholder remains.** This upstream image is pinned to a Docker Hub index digest dated 2026-10-23; re-verify before a later rebuild. The upstream already stages Chromium and ffmpeg; the derived image adds Playwright Python, actual `tini`, and Romanian-capable fonts. The image build and restricted/non-root runtime remain unverified until this workflow and pod smoke tests run.

## Secret and GitOps gates

The user authorized exactly one phase-1 credential class: `hermes serve` basic auth. **No token/password/Secret manifest is in this repo.** After Mihai approves and merges the policy PR, first confirm Argo created the restricted namespace and all policies, and prove deny/allow behavior with a bounded probe. Only **then** create `marketing-agent-serve-auth` imperatively in `marketing-agent`, using three keys: `username`, random `password`, and random `signing-secret`. Generate them only on k3s-server-01 in process memory, send a Secret manifest to `sudo k3s kubectl create -f -` via stdin; do not echo the payload, use a command-line argument, or save it in a file. The Deployment references all keys, so its container **cannot start** until this Secret is created. This deliberate temporary `CreateContainerConfigError` is safer than permitting the pod to run before enforcement. Only Mihai reads the password locally on that VM:

```bash
sudo k3s kubectl -n marketing-agent get secret marketing-agent-serve-auth -o jsonpath='{.data.password}' | base64 -d; printf '\n'
```

The upstream non-loopback `serve` auth uses `HERMES_DASHBOARD_BASIC_AUTH_USERNAME`, `_PASSWORD`, `_SECRET`; never rely on a made-up `HERMES_SERVE_PASSWORD` variable. Verify `/api/status` reports `auth_required: true` and includes provider `basic` before an ingress is added. Other provider/email/Telegram credentials and the marketing profile/SOUL are Phase 2.

Mihai's explicit Tier 3 `da` **after reviewing this PR** is required before merging the NetworkPolicies. ArgoCD root and child Applications auto-sync on merge. Resource waves apply namespace (-3), default-deny (-2), DNS/public egress and Traefik ingress exceptions (-1), PVC/Service (0), and Deployment (+1). This orders object creation but is **not an atomic security transaction or proof of instantaneous CNI enforcement**. For a formal guarantee that the pod *never* runs before policy enforcement, first apply/verify policy separately and only then allow the workload: that conflicts with the requested single sync. Do not claim the single sync proves a zero-race guarantee.

No Ingress, middleware, or Pi-hole DNS record is in this PR. A *separate* Tier 3 Traefik Local change must be approved, merged and verified from two LAN clients before an ingress/allowlist/DNS PR. Existing routes must stay healthy. The six listed private/LAN/API targets must fail from inside the marketing pod; public HTTPS and DNS must work. Treat any unintended reachability as a release blocker, and roll back by reverting the workload through a new PR under the applicable approval tier, **not by deleting the PVC**.

## Verification after separately approved merge

- Check ArgoCD marketing-agent and marketing-agent-alerts Synced/Healthy; pod admitted by `restricted`, running only on amd64 k3s-server-01; `automountServiceAccountToken: false` and no token in mounts.
- Check home directory is writable as UID 10000; `fsGroup` does not itself prove a local-path hostPath is writable. Current local-path setup creates directories mode 0777. Its `5Gi` request is **not a disk quota**.
- `hermes serve` returns an authenticated status, image uses *real* tini as PID 1 and no root/s6 init. Test HTTPS/DNS success, six blocked target IPs (`192.168.1.1`, `.10`, `.128`, `.200`, `10.43.0.1`, `100.77.241.127`), idle and trusted-page Chromium memory, Romanian capitals/lowercase rendering, and SQLite persistence after replacing the pod.
- The disk alert lives in namespace `monitoring`, with Prometheus label `release=kube-prometheus-stack`; at 2026-11-01 the live root metric was `node_filesystem_avail_bytes{instance="192.168.1.201:9100",mountpoint="/",fstype="ext4"}` (about 20.33 GiB available). Rule thresholds: warning <12Gi for 10m, critical <8Gi for 5m. Current Alertmanager receiver is `null`: no Telegram notification until the separate future task.
- Do not run Chromium on inbound email/open web. Phase-2 SOUL will limit it to owned templates and Showroom pages; web research uses fetch/search. No LAN or outside-LAN ingress is approved in this PR.
