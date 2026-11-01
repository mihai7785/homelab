# Marketing agent: gated rollout (not deployment authorization)

This PR is **draft and must not merge yet**. `:pending-build` in the Deployment intentionally points to no image; replace it by `ghcr.io/mihai7785/marketing-agent@sha256:<actual GHCR digest>` in a reviewed PR after the image is built and its amd64 manifest is checked. No workflow is changed by Hermes. Mihai owns `.github/workflows/`.

## Workflow for Mihai to add

Copy the following complete YAML into `.github/workflows/marketing-agent-ci.yaml` **on the default branch (`main`)** yourself; GitHub requires a `workflow_dispatch` workflow to exist on the default branch before it can be run manually. It is intentionally *not* in that directory in this PR. Once your workflow commit is on `main`, Hermes will update/rebase this PR branch onto that commit, so the workflow is also present at the dispatched ref; this is not a workflow edit by Hermes. It builds only when manually dispatched on the reviewed `agent/marketing-agent-isolation` branch, pushes an immutable SHA tag, reports a registry digest and never commits to `main` or edits GitOps. The repository's `packages: write` permission must be available to GitHub Actions; no personal token is needed.

```yaml
name: marketing-agent image
on:
  workflow_dispatch:
permissions:
  contents: read
  packages: write
jobs:
  build-amd64:
    if: github.ref == 'refs/heads/agent/marketing-agent-isolation'
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

After the workflow lands on `main` and this branch is updated to include it, run it on this PR's reviewed head (e.g. `gh workflow run marketing-agent-ci.yaml --ref agent/marketing-agent-isolation`), verify the job, digest and architecture, then replace `:pending-build` by the reported digest via a new commit on this branch. **Do not merge while the placeholder remains, while GHCR anonymous pull is unverified, or while the node-host egress blocker below remains unresolved.** The image may be public-readable in GHCR, or a separately approved registry pull credential would be required; neither is assumed here. This upstream image is pinned to a Docker Hub index digest dated 2026-10-23; re-verify before a later rebuild. The upstream already stages Chromium and ffmpeg; the derived image adds Playwright Python, actual `tini`, and Romanian-capable fonts, and exports `AGENT_BROWSER_EXECUTABLE_PATH` because the upstream s6 hook is bypassed. The image build and restricted/non-root runtime remain unverified until this workflow and pod smoke tests run.

## Secret and GitOps gates

The user authorized exactly one phase-1 credential class: `hermes serve` basic auth. **No token/password/Secret manifest is in this repo.** After Mihai approves and merges the policy PR, first confirm Argo created the restricted namespace and all policies, and prove deny/allow behavior with a bounded probe. Only **then** create `marketing-agent-serve-auth` imperatively in `marketing-agent`, using three keys: `username`, random `password`, and random `signing-secret`. Generate them only on k3s-server-01 in process memory, send a Secret manifest to `sudo k3s kubectl create -f -` via stdin; do not echo the payload, use a command-line argument, or save it in a file. The Deployment references all keys, so its container **cannot start** until this Secret is created. This deliberate temporary `CreateContainerConfigError` is safer than permitting the pod to run before enforcement. Only Mihai reads the password locally on that VM:

```bash
sudo k3s kubectl -n marketing-agent get secret marketing-agent-serve-auth -o jsonpath='{.data.password}' | base64 -d; printf '\n'
```

The upstream non-loopback `serve` auth uses `HERMES_DASHBOARD_BASIC_AUTH_USERNAME`, `_PASSWORD`, `_SECRET`; never rely on a made-up `HERMES_SERVE_PASSWORD` variable. Verify `/api/status` reports `auth_required: true` and includes provider `basic` before an ingress is added. Other provider/email/Telegram credentials and the marketing profile/SOUL are Phase 2.

Mihai's explicit Tier 3 `da` **after reviewing this PR** is required before merging the NetworkPolicies. ArgoCD root and child Applications auto-sync on merge. Resource waves apply namespace (-3), default-deny (-2), DNS/public egress and Traefik ingress exceptions (-1), PVC/Service (0), and Deployment (+1). This orders object creation but is **not an atomic security transaction or proof of instantaneous CNI enforcement**. For a formal guarantee that the pod *never* runs before policy enforcement, first apply/verify policy separately and only then allow the workload: that conflicts with the requested single sync. Do not claim the single sync proves a zero-race guarantee.

## Hard isolation blocker — do not deploy until resolved

Kubernetes explicitly allows traffic between a pod and **its own node** regardless of NetworkPolicy (`https://kubernetes.io/docs/concepts/services-networking/network-policies/`). This Deployment is pinned to `k3s-server-01` at `192.168.1.201`: the policy alone **cannot meet** the requirement that it reaches nothing on the LAN/cluster, even if the six originally listed targets fail. The proposed extra non-public IPv4 exclusions (0/8, 127/8, 198.18/15, multicast and reserved space) are defense in depth, not a remedy for this node exception. No firewall, CNI, node or namespace change is approved here. Obtain Mihai's architectural decision and a **separate Tier 3 plan/approval** for a verified host-level egress boundary or a different isolation architecture before any merge. A test pod must explicitly probe `192.168.1.201` and Service-IP NAT behavior (including `10.43.0.1` and CoreDNS) under the real CNI; do not claim success from manifest review.

No Ingress, middleware, or Pi-hole DNS record is in this PR. A *separate* Tier 3 Traefik Local change must be approved, merged and verified from two LAN clients before an ingress/allowlist/DNS PR. Existing routes must stay healthy. The six listed private/LAN/API targets **and the local node `192.168.1.201`** must fail from inside the marketing pod; public HTTPS and DNS must work. Treat any unintended reachability as a release blocker, and roll back by reverting the workload through a new PR under the applicable approval tier, **not by deleting the PVC**.

## Verification after separately approved merge

- Check ArgoCD marketing-agent and marketing-agent-alerts Synced/Healthy; pod admitted by `restricted`, running only on amd64 k3s-server-01; `automountServiceAccountToken: false` and no token in mounts.
- Check home directory is writable as UID 10000; `fsGroup` does not itself prove a local-path hostPath is writable. Current local-path setup creates directories mode 0777. Its `5Gi` request is **not a disk quota**.
- `hermes serve` returns an authenticated status, image uses *real* tini as PID 1 and no root/s6 init. Test HTTPS/DNS success; all six blocked targets (`192.168.1.1`, `.10`, `.128`, `.200`, `10.43.0.1`, `100.77.241.127`) **and the node's own `192.168.1.201`** must fail. Probe Chromium using `AGENT_BROWSER_EXECUTABLE_PATH` on a trusted test page; measure idle/render memory, verify Romanian capitals/lowercase and SQLite persistence after replacing the pod.
- The disk alert lives in namespace `monitoring`, with Prometheus label `release=kube-prometheus-stack`; at 2026-11-01 the live root metric was `node_filesystem_avail_bytes{instance="192.168.1.201:9100",mountpoint="/",fstype="ext4"}` (about 20.33 GiB available). Rule thresholds: warning <12Gi for 10m, critical <8Gi for 5m, and a warning if the exact metric disappears for 10m (e.g. exporter/address changes). It monitors node disk space, **not** a PVC quota. Current Alertmanager receiver is `null`: no Telegram notification until the separate future task.
- Do not run Chromium on inbound email/open web. Phase-2 SOUL will limit it to owned templates and Showroom pages; web research uses fetch/search. No LAN or outside-LAN ingress is approved in this PR.
