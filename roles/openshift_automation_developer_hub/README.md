# openshift_automation_developer_hub

Deploys Red Hat Developer Hub (RHDH) on OpenShift with the **Ansible plug-ins for Red Hat Developer Hub** and connects it
to an existing Ansible Automation Platform (AAP). Independent of the other roles; the RHDH operator is shared with
`openshift_automation_portal` through `openshift_developer_hub_operator`. Generic: URLs, registry credentials and the
certificate authority (CA) are discovered from the cluster and the job's credentials when left empty.

Sources: AAP 2.7 extend guide, "Ansible plug-ins for Red Hat Developer Hub" (OCI delivery, sidecar, plug-in settings);
RHDH 1.10 "Installing Red Hat Developer Hub on OpenShift Container Platform" and "Configuring Red Hat Developer Hub"
(operator, Backstage custom resource (CR), presets).

1. **RHDH operator** through `openshift_developer_hub_operator` (installs it or adopts an existing Subscription).
2. **AAP sign-in and plug-in token**: an AAP OAuth application (authorization code, confidential) and an AAP API token
   with write (read and write) scope, stored right away in Secret `<name>-secrets` (`AAP_HOST_URL`, `AAP_TOKEN`,
   `OAUTH_CLIENT_ID`, `OAUTH_CLIENT_SECRET`, `BACKEND_SECRET` generated once, `ENABLE_AUTH_PROVIDER_MODULE_OVERRIDE`).
   Re-runs reuse them; a stored token that stops working is replaced.
   - **Sign-in with AAP is not in the RHDH docs** (their providers are RHBK, GitHub, Microsoft, GitLab, PingFederate,
     guest). It uses `auth-backend-module-rhaap-provider` from the same AAP `automation-portal` OCI bundle as the
     Ansible plug-ins, configured like the automation portal operator does (`auth.providers.rhaap`,
     `signInPage: rhaap`, resolver `allowNewAAPUserSignIn`; frontend sign-in page `SignInPage` and `providerSettings`
     `ansible.auth.rhaap` from the self-service plug-in).
3. **Credentials**: `dynamic-plugins-registry-auth` (`auth.json` for the OCI plug-ins; the name is fixed for operator
   deployments; default: the `registry.redhat.io` entry of the cluster global pull secret) and ConfigMap
   `<name>-ca-bundle` (cluster trusted bundle + AAP CA), mounted into the backend (`NODE_EXTRA_CA_CERTS`), the plug-in
   installer and the dev tools sidecar (`SSL_CERT_FILE` / `REQUESTS_CA_BUNDLE`), as the portal operator does.
4. **Configuration**: ConfigMaps `<name>-app-config` (`ansible.creatorService`, `ansible.rhaap`, optional
   `ansible.automationHub` / `ansible.devSpaces`, AAP sign-in, the Ansible software templates, the AAP catalog provider
   for organization users and teams, RBAC administrators) and `<name>-dynamic-plugins` (the four Ansible plug-ins from
   `oci://registry.redhat.io/ansible-automation-platform/automation-portal:<tag>`, the AAP sign-in module, the RBAC
   plug-in), labelled `rhdh.redhat.com/ext-config-sync`.
5. **Backstage CR** (`rhdh.redhat.com/v1alpha5`): app-config, dynamic plug-ins, environment Secret, route, local
   PostgreSQL, the Ansible dev tools sidecar (`adt server`, port 8000) and the CA mounts. A checksum of the CA bundle and
   both ConfigMaps is a pod annotation, so every configuration change rolls the pod. The **Developer Lightspeed**
   preset, which the 1.10 operator enables by default (an extra `lightspeed-core` sidecar that needs an LLM provider), is
   turned off unless `openshift_automation_developer_hub_lightspeed_enabled` is true.
6. Waits for the deployment, keeps the route on the expected host (custom, or OpenShift's default
   `backstage-<name>-<namespace>.<apps domain>`; returning to the default recreates the route) and sets the OAuth
   redirect URI to `<URL>/api/auth/rhaap/handler/frame`.

## Requirements

- Collections: `redhat.openshift` and `kubernetes.core` (Red Hat certified). AAP gateway calls use `ansible.builtin.uri`
  (client secrets and token values only come back from the create calls).
- Credentials (in AAP, attach both): *OpenShift API (configuration as code)* (cluster-admin: operator, global pull
  secret) and *Red Hat Ansible Automation Platform* (`aap_hostname` / `aap_token`; rights to create OAuth applications).
  The plug-in token belongs to the same AAP user.
- Users from external identity providers (LDAP, SAML) need the AAP setting "Allow external users to create OAuth2
  tokens" (an AAP-wide change; not made here).

## Variables

See `defaults/main.yml`. Inputs normally supplied by the job template survey:

| Variable | Default | Notes |
|---|---|---|
| `openshift_automation_developer_hub_namespace` / `_name` | `developer-hub` / `developer-hub` | |
| `openshift_automation_developer_hub_manage_operator` | `true` | Shared role; its `openshift_developer_hub_operator_*` variables apply |
| `openshift_automation_developer_hub_route_host` | `""` | Empty = `backstage-<name>-<namespace>.<apps domain>` |
| `openshift_automation_developer_hub_lightspeed_enabled` | `false` | Developer Lightspeed preset (needs an LLM provider) |
| `openshift_automation_developer_hub_platform_url` / `_platform_token` | `""` | Empty = `aap_hostname` / `aap_token` |
| `openshift_automation_developer_hub_oauth_app_name` / `_organization` | `Red Hat Developer Hub` / `Default` | |
| `openshift_automation_developer_hub_recreate_oauth_app` | `false` | Deletes and recreates the AAP OAuth application |
| `openshift_automation_developer_hub_plugin_token` / `_rotate_plugin_token` | `""` / `false` | Empty = keep the stored token or create one |
| `openshift_automation_developer_hub_catalog_organizations` | `[Default]` | First entry: organization whose users and teams sync |
| `openshift_automation_developer_hub_plugins_image` / `_plugins_tag` | `.../automation-portal` / `2.2` | |
| `openshift_automation_developer_hub_devtools_image` / `_devtools_resources` | docs defaults | |
| `openshift_automation_developer_hub_automation_hub_url` | `""` | Empty = AAP URL; `none` = no link |
| `openshift_automation_developer_hub_dev_spaces_url` | `""` | Optional OpenShift Dev Spaces link |
| `openshift_automation_developer_hub_admin_users` / `_super_users` | `[]` | `user:default/<AAP username>`, `group:default/<team>` |
| `openshift_automation_developer_hub_registry_username` / `_password` | `""` | Empty = cluster global pull secret |
| `openshift_automation_developer_hub_validate_certs` / `_check_ssl` | `true` / `true` | This job / Developer Hub verify certificates |
| `openshift_automation_developer_hub_ca_certificate` | `""` | CA for AAP; empty = OpenShift ingress CA |
| `openshift_automation_developer_hub_app_config_overrides` / `_backstage_spec_overrides` | `{}` | Merged over the generated configuration |

## Verify

Open the reported URL and sign in with an AAP account (browser). The **Ansible** entry in the navigation opens the
plug-ins' landing page; the Create page lists the Ansible software templates (super users can create projects). AAP
users and teams appear in the catalog after the first sync (every `catalog_sync_interval` minutes).
