# ADR-003: Certificate Management Strategy

**Date:** 2025-02  
**Status:** Accepted

## Context

The homelab has a mix of HTTP and HTTPS services with inconsistent certificate management. Some services use self-signed certificates (browser warnings on every visit), some use HTTP only, and Nginx Proxy Manager handles TLS termination inconsistently. The goal is to reach a state where:

- Every service is accessible via HTTPS with no browser warnings
- Certificates are issued and renewed automatically — no manual intervention
- The approach mirrors what production environments use

Three approaches were considered:

**Option A — Self-signed certificates per service.** Each service generates its own certificate. Simple, no dependencies. Browsers show warnings unless the cert is manually trusted everywhere.

**Option B — Single internal CA (step-ca) + cert-manager.** A self-hosted Certificate Authority signs all internal certificates. The CA root certificate is added to browsers/OS once. cert-manager in Kubernetes automates issuance and renewal.

**Option C — Let's Encrypt only.** All services use publicly-trusted certificates from Let's Encrypt via DNS-01 challenge. No browser configuration required. Requires a public domain and a supported DNS provider (Cloudflare).

## Decision

**Hybrid: Option B for internal services + Option C for any externally-referenced services.**

Specifically:
- Deploy **step-ca** as an internal CA (LXC container on main Proxmox)
- Deploy **cert-manager** in the k3s cluster
- Configure a `ClusterIssuer` pointing to step-ca for `*.homelab.local` services
- Configure a second `ClusterIssuer` pointing to Let's Encrypt for any services with a real domain, using Cloudflare DNS-01 challenge
- Add the step-ca root certificate to all client browsers and OS trust stores

## Rationale

1. **No open ports required.** DNS-01 challenge for Let's Encrypt means Let's Encrypt never needs to reach the homelab. The challenge is fulfilled by temporarily creating a DNS TXT record via the Cloudflare API. No port forwarding needed.

2. **Automation.** cert-manager handles the full certificate lifecycle — request, issuance, renewal, and injection into Kubernetes Secrets. No manual certificate management after initial setup.

3. **Real-world pattern.** This two-tier approach (internal CA for internal services, public CA for external) is exactly what enterprises use. Internal services use corporate CAs; external-facing services use DigiCert, Let's Encrypt, or similar.

4. **Learning value.** Setting this up requires understanding: X.509 certificate structure, CA trust chains, ACME protocol, Kubernetes Secrets, and cert-manager CRDs. These topics appear frequently in platform engineering interviews.

## Consequences

- All internal service certificates will show as trusted only on devices that have the step-ca root certificate installed. This is a one-time setup per device.
- cert-manager must be deployed before any service certificates are configured in the cluster.
- The step-ca root certificate must be rotated eventually (default validity is 10 years — acceptable for a homelab).
- Cloudflare DNS-01 requires moving the domain's nameservers to Cloudflare (free). This is a one-time change.

## PKI Concepts Reference

**Certificate Authority (CA):** An entity trusted to sign certificates. When you add a CA's root cert to your browser, you trust everything that CA has signed.

**X.509:** The standard format for certificates. Contains: subject (who this cert is for), issuer (who signed it), public key, validity period, and the issuer's signature.

**TLS handshake:** When your browser connects to `https://service`, the server presents its certificate. The browser checks: (1) is it signed by a trusted CA? (2) is the hostname correct? (3) is it still valid? If yes to all three, the padlock appears.

**DNS-01 challenge:** Let's Encrypt asks "prove you control this domain by creating a DNS TXT record with this value." cert-manager uses the Cloudflare API to create and delete the record automatically. Let's Encrypt verifies it and issues the certificate.
