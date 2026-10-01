# ADR-008: One k3s Server with Raspberry Pi Workers

**Date:** 2026-10-01
**Status:** Accepted

## Context

The cluster previously used VM 301 as its k3s server and VMs 302/303 as workers.
The three Raspberry Pis are now available as ARM64 worker nodes. Keeping extra
worker VMs consumes Proxmox resources without adding a second control plane.

## Decision

Run one k3s server (`k3s-server-01`, VM 301, amd64) and three Pi workers:
`raspberry-agentic-main`, `raspberry-agentic-slave1`, and
`raspberry-agentic-slave2` (ARM64). Retire worker VMs 302 and 303. ArgoCD remains
the source of workload reconciliation; this is not a high-availability control plane.

## Consequences

- Loss of VM 301 interrupts the control plane; backups and a tested recovery
  procedure matter more than worker count.
- Workloads need multi-architecture images or an explicit amd64 nodeSelector.
  Write-heavy workloads should not be scheduled on Pi nodes with `storage=sdcard`.
- Storage and node failure domains remain distinct: adding a Pi worker does not
  make a local-path PVC on VM 301 portable or highly available.