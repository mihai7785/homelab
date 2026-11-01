#!/usr/bin/env bash
# Build on dockerhome, stream to k3s containerd, and remove only this build's cache.
set -Eeuo pipefail

here=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
cd "$here"
for cmd in ssh tar sha256sum; do command -v "$cmd" >/dev/null; done
ssh_opts=(-o BatchMode=yes -o StrictHostKeyChecking=yes -o ConnectTimeout=8)
source_hash=$(sha256sum Dockerfile entrypoint.sh | sha256sum | cut -c1-16)
image="localhost/marketing-agent:phase1-${source_hash}"
builder="marketing-agent-${source_hash}-$$"
helper_preexisting=1

remote() { ssh "${ssh_opts[@]}" dockerhome "$@"; }
node() { ssh "${ssh_opts[@]}" k3s-server-01 "$@"; }
cleanup() {
  remote "docker buildx rm --force '$builder' >/dev/null 2>&1" || true
  if (( helper_preexisting == 0 )); then
    # Remove only the BuildKit helper pulled for this run; refuse if in use.
    remote 'docker image rm moby/buildkit:buildx-stable-1 >/dev/null 2>&1' || true
  fi
}
trap cleanup EXIT

# This is intentionally not docker system/image/volume prune: other services
# use this daemon. This private buildx builder is the only intermediate cache.
docker_free=$(remote 'df -Pk /var/lib/docker | awk "NR==2 {print \$4}"')
node_free=$(node 'df -Pk /var/lib/rancher/k3s | awk "NR==2 {print \$4}"')
printf 'Image: %s; free KiB dockerhome=%s k3s-server-01=%s\n' "$image" "$docker_free" "$node_free"
# A trial build on 2026-11-01 fell from 4.6 GiB to 0.8 GiB free before
# loading the final image. Preserve headroom for NPM and other services.
min_docker_kib=$((8 * 1024 * 1024))
min_node_kib=$((8 * 1024 * 1024))
if (( docker_free < min_docker_kib || node_free < min_node_kib )); then
  echo 'Insufficient disk headroom (8 GiB required on each host); no build or import attempted.' >&2
  exit 1
fi
if ! remote 'docker image inspect moby/buildkit:buildx-stable-1 >/dev/null 2>&1'; then
  helper_preexisting=0
fi
remote "docker buildx create --name '$builder' --driver docker-container --bootstrap >/dev/null"
tar -cf - Dockerfile entrypoint.sh | remote "docker buildx build --builder '$builder' --platform linux/amd64 --progress=plain --load --tag '$image' -"
remote "docker image inspect '$image' --format 'Built image={{.Id}} size={{.Size}} architecture={{.Architecture}}'"
# The only target is the k8s.io namespace in this server's k3s containerd.
remote "docker save '$image'" | node 'sudo -n k3s ctr -n k8s.io images import -'
node "sudo -n k3s ctr -n k8s.io images ls -q | grep -Fx '$image' >/dev/null"
node "sudo -n k3s ctr -n k8s.io images check | grep -F '$image'"
printf 'Imported %s into k3s containerd (namespace k8s.io); removing dedicated build cache.\n' "$image"
