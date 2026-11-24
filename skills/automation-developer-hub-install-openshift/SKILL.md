---
name: automation-developer-hub-install-openshift
description: >-
  Install or troubleshoot Red Hat Developer Hub (RHDH) with the Ansible plug-ins on OpenShift with the
  openshift_automation_developer_hub role, and the shared openshift_developer_hub_operator role (RHDH operator, also used
  by the automation portal) - Backstage custom resource, OCI dynamic plug-ins, Ansible Automation Platform (AAP) sign-in,
  plug-in token, CA bundle, Developer Lightspeed preset. Use when editing those roles or debugging Developer Hub.
---

# Red Hat Developer Hub with the Ansible plug-ins

Roles: `roles/openshift_automation_developer_hub` (playbook `playbooks/openshift_automation_developer_hub.yml`, area
`configs/automation_developer_hub`, job template "Developer Hub | Install with the Ansible plug-ins on OpenShift") and the
shared `roles/openshift_developer_hub_operator`. Docs: AAP 2.7 extend guide "Ansible plug-ins for Red Hat Developer Hub"
(OCI delivery) and the RHDH docs **matching the installed operator version** (1.10 here; newer RHDH docs may differ).

## Operator (shared role)
- RHDH supports only the **All namespaces** install mode; recommended namespace `rhdh-operator`, channel `fast` or
  `fast-<version>`.
- Exactly one Subscription to package `rhdh` per cluster: the role adopts an existing one in any namespace (console
  install, or the automation portal operator's in `openshift-operators`) instead of creating a second.
- One OperatorGroup per namespace: the role only creates one if the namespace has none.

## Instance
- The operator names everything `backstage-<CR name>` (Deployment, Route, Service; database `backstage-psql-<name>`) and
  sets `app.baseUrl` / `backend.baseUrl` / `backend.cors.origin` from the route.
- OCI plug-ins need Secret **`dynamic-plugins-registry-auth`** (fixed name) with `auth.json`; image
  `registry.redhat.io/ansible-automation-platform/automation-portal:<tag>!<plugin>`, tag `2.2` verified. Check
  `oc logs <pod> -c install-dynamic-plugins` for `Successfully installed dynamic plugin`.
- **Developer Lightspeed is on by default in operator 1.10** (`lightspeed-core` sidecar + `init-rag-data` init
  container, needs an LLM). Turn it off with `spec.flavours: [{name: lightspeed, enabled: false}]` (role default).
- AAP sign-in is not in the RHDH docs: `auth-backend-module-rhaap-provider` from the same OCI bundle,
  `auth.providers.rhaap.production` (`host`, `clientId`, `clientSecret`, `checkSSL`, resolver `allowNewAAPUserSignIn`),
  `signInPage: rhaap`, env `ENABLE_AUTH_PROVIDER_MODULE_OVERRIDE=true` (copied from the automation portal operator's
  generated config). OAuth redirect `<URL>/api/auth/rhaap/handler/frame`.
- The **frontend** half of AAP sign-in lives in the self-service plug-in's config: `signInPage: {importName: SignInPage}`
  and `providerSettings` with `provider: ansible.auth.rhaap` (plus `AAPLogoutButton` on `global.header/profile`).
  Without it the sign-in page shows only RHDH's default GitHub button, which fails with `Unknown auth provider 'github'`
  (the backend has only `rhaap`). Check the backend side with `curl <URL>/api/auth/rhaap/start?env=production` (302 to
  `<AAP>/o/authorize/`).
- CA trust: one ConfigMap mounted into the backend and init container (`NODE_EXTRA_CA_CERTS`) and the dev tools sidecar /
  installer (`SSL_CERT_FILE`, `REQUESTS_CA_BUNDLE`, which **replace** the trust store, so include public CAs).
  Symptom when missing or broken: catalog logs `fetch failed`; in the pod,
  `node -e 'fetch("https://<aap>/api/gateway/v1/ping/")'` shows `SELF_SIGNED_CERT_IN_CHAIN`, and a malformed bundle
  logs `Ignoring extra certs ... bad end line`.
- **Ansible gotcha:** build PEM joins (`a ~ '\n' ~ b`) in a double-quoted YAML string; in a folded block (`>-`) the
  `'\n'` stays a literal backslash-n and breaks the PEM file.
- Config changes: ConfigMaps/Secret carry `rhdh.redhat.com/ext-config-sync: "true"`; the role also sets a pod annotation
  with a checksum of the CA bundle and ConfigMaps (the CA is mounted via the deployment patch, which the operator
  doesn't watch).
- Catalog sync (`AapEntityProvider`) runs every `catalog_sync_interval` minutes; the schedule lives in the database, so a
  restart doesn't run it early. Check the token against the gateway organizations and users endpoints (curl with the stored token).
- Route host: OpenShift generates it only at creation; returning to the default needs the route deleted and the
  Backstage CR annotated (the operator doesn't watch routes). The role does both.
