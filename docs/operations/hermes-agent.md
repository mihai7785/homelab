# Hermes Agent access to the homelab

Hermes runs as the unprivileged `hermes` user on a dedicated VM, without local
`sudo`. The table describes configured access, not blanket permission to use it.

| System | Identity and access level | Technical boundary |
| --- | --- | --- |
| Proxmox VE (three nodes) | Dedicated API identity for read-only inventory and task checks; a separate operator identity for approved VM operations on `homelab`. No hypervisor shell/root access. | Operator permissions are scoped to the `agent-managed` VM pool; the client checks live pool membership and exposes no pool-membership changes. New VM clones are limited to approved templates and VMIDs 400–499. Existing backups and the PBS datastore are off-limits. |
| Raspberry Pis (`rpi-main`, `rpi-slave1`, `rpi-slave2`) | SSH as `hermes`; `sudo -n` can run root commands. | Root sessions are logged. This is broad host privilege, **not** a technical read-only sandbox; the restrictions below are policy. |
| `dockerhome` | SSH as `hermes`, Docker group membership, and logged `sudo -n` root access. | Docker/root privileges are broad; policy restricts changes. Nginx Proxy Manager is managed through its API, never by editing its files or database. |
| Nginx Proxy Manager | Non-admin `hermes@homelab.local` API account; read and approved changes to proxy hosts, redirects, and certificates. | API account role and API surface; no NPM administrator identity. |
| Pi-hole DNS | API access to the primary (writable) and secondary (read-only). | The secondary does not grant write capability; changes go only to the primary and replication is checked afterward. |
| Synology NAS | Non-admin `hermes` File Station account; read-only on media/download shares, read/write in its own share. SNMP is read-only; a dedicated NFS area holds agent reports and rollback material. | Share permissions limit DSM access; no DSM administrator role or PBS datastore management. |
| GitHub `mihai7785/homelab` | `mihai-hermes-bot` has repository write access. | Protected `main`: work starts from `origin/main` on an `agent/*` branch and goes through a PR for Mihai to review and merge. No workflow, ruleset, or collaborator changes. |

## Approval and safety rules

- Read-only status, logs, and inventory checks may run without approval. Before
  **any change outside the agent's own workspace**, Hermes states the change,
  reason, exact command/API call, and rollback, then waits for Mihai's explicit
  `da` or `ok`. A merged PR alone does not approve a live deployment.
- Destructive operations, DNS/network changes, and actions involving backups
  require explicit confirmation. VM deletion needs its **own** confirmation;
  destructive VM work requires a completed, verified backup first. Hermes never
  modifies, deletes, or prunes existing backups or the PBS datastore.
- Proxmox writes use an approved JSON plan with SHA-256 and verify the resulting
  task to completion. NPM changes require a saved JSON snapshot and post-change
  proxy checks; Pi-hole changes require a Teleporter export and verification on
  the secondary. Never commit credentials or sensitive snapshots to Git, or
  store credential files on the NAS share.
- On Raspberry Pis, Hermes never changes SSH access, users, `sudoers`, or the
  firewall. On `dockerhome`, NPM restarts require explicit approval, and volume
  deletion requires its own confirmation. Prefer GitOps/ArgoCD and AWX to ad-hoc
  changes where applicable. Hermes does not approve or merge its own PRs.
