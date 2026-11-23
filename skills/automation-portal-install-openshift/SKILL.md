---
name: automation-portal-install-openshift
description: >-
  Install or troubleshoot Ansible automation portal on OpenShift with the ansible_automation_portal role -
  automation portal operator (Technology Preview), AutomationPortal custom resource (CR), Red Hat Developer Hub
  (RHDH) operator, Ansible Automation Platform (AAP) OAuth application and catalog synchronization token, portal
  sign-in and catalog sync failures. Use when editing that role or debugging a portal install.
---

# Install Ansible automation portal on OpenShift

Role: `roles/ansible_automation_portal` (playbook `playbooks/ansible_automation_portal.yml`, area
`configs/automation_portal`, job template "Automation portal | Install on OpenShift"). Independent of the Automation
Orchestrator roles. Source of truth: AAP 2.7 install guide, chapter "Install automation portal on OpenShift using the
operator" (the Helm chart chapter is the other, older method; don't mix them).

## How it fits together
- Two operators: the **automation portal operator** reads `AutomationPortal` (`automationportal.aap.redhat.com/v1alpha1`),
  validates the Secrets, generates the dynamic plugin config and creates a `Backstage` CR; the **RHDH operator**
  turns that into the Deployment, Service, Route and local PostgreSQL. The portal operator installs RHDH itself if missing
  (OLM Subscription, or ClusterExtension on OLM v1); an existing RHDH install is reused.
- Package `automation-portal-operator` in `redhat-operators`, channel `fast`. Install modes Own/Single/AllNamespaces;
  the role uses OwnNamespace in the portal namespace, like the guide.
- Status: `status.phase` Pending -> Running; conditions `RHDHOperatorReady`, `SecretsValid`, `PluginsConfigured`,
  `DeploymentReady` (docs: `BackstageReady`), `Ready`.

## Where the operator (2.3.x) differs from the AAP 2.7 docs (verified on a cluster; trust the CRD)
- Pod settings are `spec.deployment.*` (`caCertificates`, `route`, `image`, `replicas`, `resources`, ...), not
  `spec.backstage.*`. The API server **silently drops** unknown fields, so a docs-style `spec.backstage` block is ignored
  with no error. Check fields with `oc get crd automationportals.automationportal.aap.redhat.com -o json`.
- `status.url` stays empty; `status.deploymentCR` (docs: `backstageCR`) names the Backstage CR, and the RHDH route is
  `backstage-<deploymentCR>` (host `backstage-<name>-<namespace>.<apps domain>`). The role reads the route.
- With `caCertificates`, only `NODE_EXTRA_CA_CERTS` is set (adds to the default trust store); no `SSL_CERT_FILE`.
- Containers in the portal pod: `backstage-backend` and `ansible-devtools-server`.

## Secrets (names matter)
- `secrets-rhaap-portal` (`spec.aap.credentials.secretRef`): `aap-host-url`, `oauth-client-id`, `oauth-client-secret`,
  `aap-token`. The operator rejects missing/empty keys and placeholder values (`<...>`, `changeme`).
- `<CR name>-registry-auth`: `auth.json` used by the plugin init container (skopeo; ignores imagePullSecrets). Required in
  connected clusters too.
- `spec.deployment.caCertificates.secretRef`: key `ca-bundle.crt`. The docs say the operator also points `SSL_CERT_FILE` /
  `REQUESTS_CA_BUNDLE` at it (which would replace the default trust store), so the role puts the cluster trusted bundle
  (public CAs) plus the AAP CA in it either way. Prefer this over `spec.aap.checkSSL: false`. Without it, catalog sync
  logs `fetch failed` (Node.js `SELF_SIGNED_CERT_IN_CHAIN`) for an AAP behind a private CA.

## AAP side
- OAuth application: authorization code, confidential, redirect `<portal URL>/api/auth/rhaap/handler/frame`. Sign-in
  fails until the redirect matches the real URL; the role sets it after the CR is Running.
- Catalog token: AAP API token, **write** scope. Only job templates its user can see are synchronized; portal users
  still need Execute on a job template in AAP to run it.
- AAP returns client secrets and token values only on create. The role keeps them in `secrets-rhaap-portal`; if the
  OAuth app exists without a matching Secret, rerun with `ansible_automation_portal_recreate_oauth_app=true`.
- External identity provider users (LDAP, SAML, ...) need AAP setting "Allow external users to create OAuth2 tokens"
  (`ALLOW_OAUTH2_FOR_EXTERNAL_USERS`, gateway settings); local users don't.
- Portal admins: `spec.permissions.adminUsers` entries `user:default/<AAP username>` / `group:default/<team>`. Portal RBAC
  roles for other users are created in the portal UI (Administration > RBAC; catalog.entity.read + scaffolder permissions).

## Troubleshooting
```bash
oc get automationportal -n <ns> <name> -o jsonpath='{range .status.conditions[*]}{.type}={.status} {.message}{"\n"}{end}'
oc get backstage,pods,route -n <ns>
oc logs -n <ns> deploy/<backstage deployment> -c install-dynamic-plugins   # plugin pull / registry auth problems
oc logs -n <ns> -l app.kubernetes.io/name=automation-portal-operator       # operator reconcile errors
```
- `SecretsValid=False`: the message names the Secret/key.
- Catalog sync runs as scheduled tasks (`AapEntityProvider`, `AAPJobTemplateProvider`) every `syncInterval` minutes; the
  schedule lives in the portal database, so a pod restart does not run it early. Use the portal's manual sync to refresh now.
- Catalog empty: check the token user's visibility, `spec.plugins.catalog.orgs` (single-org deployments only use the
  first entry) and label filters; changes appear after the next sync (`syncInterval`, minutes).
- Anything not exposed as a role variable: `ansible_automation_portal_spec_overrides` (merged into the spec), e.g. an
  external database (`spec.database.enableLocalDb: false` + `authSecretName`, user needs CREATEDB).
