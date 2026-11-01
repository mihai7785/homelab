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

After the workflow lands on `main` and this branch is updated to include it, run it on this PR's reviewed head (e.g. `gh workflow run marketing-agent-ci.yaml --ref agent/marketing-agent-isolation`), verify the job, digest and architecture, then replace `:pending-build` by the reported digest via a new commit on this branch. **Do not merge while the placeholder remains or while GHCR anonymous pull is unverified.** The own-node exception below is a specifically accepted phase-1 risk, not a requirement to change host networking now. The image may be public-readable in GHCR, or a separately approved registry pull credential would be required; neither is assumed here. This upstream image is pinned to a Docker Hub index digest dated 2026-10-23; re-verify before a later rebuild. The upstream already stages Chromium and ffmpeg; the derived image adds Playwright Python, actual `tini`, and Romanian-capable fonts, and exports `AGENT_BROWSER_EXECUTABLE_PATH` because the upstream s6 hook is bypassed. The image build and restricted/non-root runtime remain unverified until this workflow and pod smoke tests run.

## Secret and GitOps gates

The user authorized exactly one phase-1 credential class: `hermes serve` basic auth. **No token/password/Secret manifest is in this repo.** After Mihai approves and merges the policy PR, first confirm Argo created the restricted namespace and all policies, and prove deny/allow behavior with a bounded probe. Only **then** create `marketing-agent-serve-auth` imperatively in `marketing-agent`, using three keys: `username`, random `password`, and random `signing-secret`. Generate them only on k3s-server-01 in process memory, send a Secret manifest to `sudo k3s kubectl create -f -` via stdin; do not echo the payload, use a command-line argument, or save it in a file. The Deployment references all keys, so its container **cannot start** until this Secret is created. This deliberate temporary `CreateContainerConfigError` is safer than permitting the pod to run before enforcement. Only Mihai reads the password locally on that VM:

```bash
sudo k3s kubectl -n marketing-agent get secret marketing-agent-serve-auth -o jsonpath='{.data.password}' | base64 -d; printf '\n'
```

The upstream non-loopback `serve` auth uses `HERMES_DASHBOARD_BASIC_AUTH_USERNAME`, `_PASSWORD`, `_SECRET`; never rely on a made-up `HERMES_SERVE_PASSWORD` variable. Verify `/api/status` reports `auth_required: true` and includes provider `basic` before an ingress is added. The **only** phase-1 credential exception is this serve auth Secret; no model/API, email, Telegram or other agent credentials and no untrusted/external content reach the agent before phase 4. The marketing profile/SOUL remains out of scope for this PR (planned separately in phase 2); any such later setup must preserve the phase-4 gate.

Mihai's explicit Tier 3 `da` **after reviewing this PR** is required before merging the NetworkPolicies. ArgoCD root and child Applications auto-sync on merge. Resource waves apply namespace (-3), default-deny (-2), DNS/public egress and Traefik ingress exceptions (-1), PVC/Service (0), and Deployment (+1). This orders object creation but is **not an atomic security transaction or proof of instantaneous CNI enforcement**. For a formal guarantee that the pod *never* runs before policy enforcement, first apply/verify policy separately and only then allow the workload: that conflicts with the requested single sync. Do not claim the single sync proves a zero-race guarantee.

## Accepted phase-1 risk: own-node reachability

Kubernetes explicitly allows traffic between a pod and **its own node** regardless of NetworkPolicy (`https://kubernetes.io/docs/concepts/services-networking/network-policies/`). This Deployment is pinned to `k3s-server-01` at `192.168.1.201`; access to that node is **not** blocked by these policies. Mihai explicitly accepted this exception **for phase 1 only** in chat on 2026-11-01, because the agent will have no model/API/email/Telegram credentials (except the explicitly authorized `hermes serve` auth Secret) and will process no untrusted/external content before phase 4. This is a documented exception, **not** proof of the original absolute no-LAN/no-cluster requirement. No firewall, CNI, node or namespace change is approved by accepting the risk. The additional non-public IPv4 exclusions are defense in depth, not a fix for the node exception. Probe `192.168.1.201` and report observed reachability without treating it as a phase-1 release failure; test Service-IP NAT, `10.43.0.1` and CoreDNS under the real CNI rather than inferring behavior from YAML.

**Mandatory before phase 4 (email/web):** inventory every `k3s-server-01` port reachable from inside this pod and the authentication state of each service; then obtain Mihai's explicit decision between targeted host rules and a dedicated VM, with a separate Tier 3 plan/approval for any network-critical change. Do **not** add email/web credentials or ingest external content before this gate is completed. This is tracked in `~/workspace/notes/k3s-backlog.md` on Hermes-lab, not by a new Kubernetes object.

No Ingress, middleware, or Pi-hole DNS record is in this PR. A *separate* Tier 3 Traefik Local change must be approved, merged and verified from two LAN clients before an ingress/allowlist/DNS PR. Existing routes must stay healthy. The six originally listed private/LAN/API targets must fail from inside the marketing pod; public HTTPS/DNS connectivity can be smoke-tested without sending external content to the agent. Report the own-node result separately as accepted risk. Any *other* unintended reachability is a release blocker; roll back by reverting the workload through a new PR under the applicable approval tier, **not by deleting the PVC**.

## Verification after separately approved merge

- Check ArgoCD marketing-agent and marketing-agent-alerts Synced/Healthy; pod admitted by `restricted`, running only on amd64 k3s-server-01; `automountServiceAccountToken: false` and no token in mounts.
- Check home directory is writable as UID 10000; `fsGroup` does not itself prove a local-path hostPath is writable. Current local-path setup creates directories mode 0777. Its `5Gi` request is **not a disk quota**.
- `hermes serve` returns an authenticated status, image uses *real* tini as PID 1 and no root/s6 init. Test public TLS/DNS connectivity in a bounded diagnostic (do not feed fetched content to the agent); all six blocked targets (`192.168.1.1`, `.10`, `.128`, `.200`, `10.43.0.1`, `100.77.241.127`) must fail. Measure and report own-node `192.168.1.201` reachability separately as the accepted phase-1 risk. Probe Chromium using `AGENT_BROWSER_EXECUTABLE_PATH` only on a trusted local template; measure idle/render memory, verify Romanian capitals/lowercase and SQLite persistence after replacing the pod.
- The disk alert lives in namespace `monitoring`, with Prometheus label `release=kube-prometheus-stack`; at 2026-11-01 the live root metric was `node_filesystem_avail_bytes{instance="192.168.1.201:9100",mountpoint="/",fstype="ext4"}` (about 20.33 GiB available). Rule thresholds: warning <12Gi for 10m, critical <8Gi for 5m, and a warning if the exact metric disappears for 10m (e.g. exporter/address changes). It monitors node disk space, **not** a PVC quota. Current Alertmanager receiver is `null`: no Telegram notification until the separate future task.
- Do not run Chromium on inbound email/open web. Phase-2 SOUL will limit it to owned templates and Showroom pages; web research through fetch/search and ingestion of email/web content starts only after the mandatory phase-4 gate. No LAN or outside-LAN ingress route is approved in this PR.
