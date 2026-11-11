# automation_orchestrator_configuration

Configures a running Red Hat Automation Orchestrator (AO) for Ansible Automation Platform (AAP). Run it after
`openshift_automation_orchestrator` (or any AO install). Generic: nothing site-specific in defaults; URLs, the admin
password and the CA are discovered from the cluster and the job's credentials when left empty.

What it does (AO 2026.8 docs in brackets):

1. **Deployment environment settings** the custom resource has no field for, re-applied every run because the operator may drop them
   on upgrade ["Allow internal service URLs for integrations"; OpenID Connect (OIDC) variables]:
   `APP_INTEGRATION_URL_ALLOWED_HOSTS` (backend, worker, background-worker; AAP host plus extras) and
   `APP_OIDC_ALLOW_PRIVATE_NETWORKS` (backend). Waits for the rollout.
2. **Ansible Automation Platform integration** for job dispatch: an AO credential of type *Ansible Automation Platform* (documented
   `/api/v1/credentials`) and an integration with `ca_certificate` so TLS stays verified, then `validate`.
   The request shape comes from the OpenAPI specification AO serves at `/api_docs/v1/openapi.json`.
3. **Single sign-on (SSO)** ["Add Ansible Automation Platform as an identity provider manually"]: AAP gateway OAuth2
   application (authorization-code, confidential, RS256) and an AO OIDC identity provider (IdP) (`idp_type: aap`),
   tested with `/identity_providers/test` before saving, then checked on the public login-provider list.
   - **AO 2026.8 quirk handled:** creating an IdP doesn't persist `client_secret` (SSO then fails with
     "authentication failed", token exchange 401). The role always follows a create with a PATCH of the full
     configuration plus the secret.
   - AAP returns the OAuth client secret only at creation. Re-runs keep the existing app when AO already uses its
     client id. If the app exists but AO doesn't use it, the role stops unless `automation_orchestrator_configuration_recreate_oauth_app`
     is true.

## Requirements

- Collections: `redhat.openshift` (Red Hat certified; applies objects) and `kubernetes.core` (Red Hat certified; lookups). AO and AAP REST calls use `ansible.builtin.uri`: there's no
  certified AO collection, and the OAuth client secret only comes back from the raw create call.
- Credentials (in AAP, attach both to the job template):
  - cluster: `K8S_AUTH_HOST` / `K8S_AUTH_API_KEY` / `K8S_AUTH_SSL_CA_CERT` (custom type *OpenShift API (configuration as code)*)
  - AAP: *Red Hat Ansible Automation Platform* credential (injects `aap_hostname` / `aap_token`); the token needs
    rights to create OAuth applications in the chosen organization.
- An AAP token or username/password for AO to store as the integration's management credential.

## Variables

See `defaults/main.yml`. Inputs normally supplied by the job template survey:

| Variable | Default | Notes |
|---|---|---|
| `automation_orchestrator_configuration_namespace` | `automation-orchestrator` | |
| `automation_orchestrator_configuration_url` | `""` | Empty = AO Route in the namespace |
| `automation_orchestrator_configuration_admin_password` | `""` | Empty = Secret `ao-admin-password` |
| `automation_orchestrator_configuration_platform_url` / `_platform_token` | `""` | Empty = `aap_hostname` / `aap_token` from the AAP credential |
| `automation_orchestrator_configuration_ca_certificate` | `""` | Empty = OpenShift ingress CA (`openshift-config-managed/default-ingress-cert`) |
| `automation_orchestrator_configuration_integration_name` | `Ansible Automation Platform` | |
| `automation_orchestrator_configuration_integration_token` or `_username` + `_password` | `""` | Stored in AO (encrypted) |
| `automation_orchestrator_configuration_integration_extra_allowed_hosts` | `[]` | List or comma-separated string |
| `automation_orchestrator_configuration_configure_single_sign_on` | `true` | `"true"`/`"false"` strings from surveys work |
| `automation_orchestrator_configuration_oauth_app_organization` | `Default` | AAP organization owning the OAuth app |
| `automation_orchestrator_configuration_identity_provider_disable_tls_verify` | `false` | IdPs have no CA field; docs say enable for internal certs |
| `automation_orchestrator_configuration_recreate_oauth_app` | `false` | Deletes and recreates the AAP OAuth app |
| `automation_orchestrator_configuration_validate_certs` | `true` | This job verifies the cluster API, AO and AAP certificates |
| `automation_orchestrator_configuration_integration_validate_certs` | `true` | AO verifies the AAP certificate; `false` sets `insecure_skip_tls_verify` |

## Verify

After the run, log out of AO and use **Log in with Ansible Automation Platform** (a browser step the role can't do).
Users are mapped from AAP: system administrators to `admins`, auditors to `auditors`, others to `users`.
