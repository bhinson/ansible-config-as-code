---
name: automation-orchestrator-platform-integration
description: >-
  Connect Red Hat Automation Orchestrator (AO) to Ansible Automation Platform (AAP)
  with the automation_orchestrator_configuration role - integration for job dispatch, AAP gateway
  OAuth app + AO OIDC identity provider (IdP) for single sign-on (SSO), private-network
  allowlists, AO REST API calls. Use when editing that role or debugging AO
  integration and SSO failures.
---

# Connect Automation Orchestrator to Ansible Automation Platform

Role: `roles/automation_orchestrator_configuration` (playbook `playbooks/automation_orchestrator_configuration.yml`), run after AO is installed (skill
`automation-orchestrator-install-openshift`). Docs (AO 2026.8 configure guide): "Configure an Ansible Automation Platform integration" and
"Add Ansible Automation Platform as an identity provider manually/automatically". AO talks to the AAP **gateway** on
443 only; AAP needs no inbound access to AO.

## Rules
- **Follow the documented API and steps.** AO serves its OpenAPI 3.1 specification at
  `https://<AO host>/api_docs/v1/openapi.json` (Swagger UI at `/api_docs/v1/docs`; develop guide, "Access and use the
  OpenAPI specification"). Take request shapes from it; don't probe or guess.
- Keep TLS verified for the integration: pass the CA that signed the AAP route as `ca_certificate`
  (the role defaults to the OpenShift ingress CA). `automation_orchestrator_configuration_integration_validate_certs:
  false` sets `insecure_skip_tls_verify` (last resort); `automation_orchestrator_configuration_validate_certs` controls
  the job's own calls.
- AAP returns the OAuth client secret **only when the app is created**. Never log it; store it in AO (and a vault if
  needed) immediately.
- Writing to AO or AAP changes live systems: run `--check` first and confirm before a real run.

## Private-network allowlists (no custom resource field)
When the AAP gateway resolves to a private IP, AO blocks it as server-side request forgery (SSRF) unless these deployment environment variables are set. The
operator can drop them on upgrade, so the role re-applies them every run; re-check after AO operator upgrades.
| Environment variable | Deployments | Symptom without it |
|---|---|---|
| `APP_INTEGRATION_URL_ALLOWED_HOSTS='["aap.example.com"]'` | backend, worker, background-worker | "base_url must not resolve to a private ... address" |
| `APP_OIDC_ALLOW_PRIVATE_NETWORKS=true` | backend | IdP test: "SSRF blocked: private IP range" |

## Integration (job dispatch)
1. AO credential of type *Ansible Automation Platform* (`POST /api/v1/credentials`, documented), holding an AAP token
   (preferred) or username/password used for health checks and discovery.
2. Integration (`IntegrationCreate` in the OpenAPI specification):
   `{name, integration_type: ansible_automation_platform, scope: global, management_credential_id,
   configuration: {integration_type, base_url, ca_certificate, allow_http: false, insecure_skip_tls_verify: false}}`.
3. `POST /api/v1/integrations/{id}/validate` must return success; status becomes `available`.

## Single sign-on
1. AAP gateway OAuth2 application: authorization-code grant, confidential client, RS256, redirect URI
   `<Automation Orchestrator URL>/api/v1/auth/oidc/callback`, post-logout redirect `<Automation Orchestrator URL>/`.
2. AO IdP at `/api/v1/identity_providers` (test with `/api/v1/identity_providers/test` before saving).
   Body: top level `name` + `provider_type: oidc`; the documented configuration fields go **inside**
   `configuration: {provider_type: oidc, idp_type: aap, issuer: https://<gateway>/o/, client_id, client_secret,
   scopes: "read write openid roles", aap_role_mapping_enabled, ...}`.
3. IdPs have **no CA field**. The docs say to set `disable_tls_verify: true` for internally signed
   certificates (the test fails otherwise).
4. Verify in a browser: log out of AO and use **Log in with Ansible Automation Platform**. AAP system administrators
   map to `admins`, auditors to `auditors`, everyone else to `users`.

## Gotchas
- **AO 2026.8: creating an IdP does not persist `configuration.client_secret`.** Symptom: SSO shows
  "authentication failed"; AO backend logs `Token exchange failed with HTTP 401`; the gateway access log shows
  `POST /o/token/ 401` from `python-httpx` with no client credentials. Fix: PATCH the provider with the **full**
  `configuration` block plus `client_secret` (PATCH rejects partial configuration). The role always does this after a create.
- **Check OAuth client credentials safely:** POST to `https://<gateway>/o/token/` with
  `grant_type=authorization_code`, a bogus `code` and the client id/secret. `invalid_grant` (400) means the credentials
  are valid; `invalid_client` (401) means they are wrong or missing.
- AO API tokens go stale when the admin user record changes (`401 TOKEN_STALE`): log in again and retry once.
- If the OAuth app exists in AAP but AO's IdP doesn't use its client id, the secret can't be recovered: the role stops
  unless `automation_orchestrator_configuration_recreate_oauth_app: true` (which invalidates the old secret).
- Re-running against objects created by hand under other names creates duplicates. Pass the existing names
  (`automation_orchestrator_configuration_integration_name`, `automation_orchestrator_configuration_integration_credential_name`, `automation_orchestrator_configuration_identity_provider_name`,
  `automation_orchestrator_configuration_oauth_app_name`).
