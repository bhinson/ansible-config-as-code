# openshift_automation_mcp

Deploys and configures the **Model Context Protocol (MCP) server for Ansible Automation Platform (AAP)** on an
operator-based AAP installation on OpenShift, and optionally the AAP OAuth application that MCP clients use for
OAuth 2.1 sign-in. Independent of the other roles. Generic: the AAP instance and the certificate authority (CA) are
discovered from the cluster and the job's credentials when left empty.

Sources: AAP 2.7 extend guide, "Deploy the MCP server on an operator-based installation", "MCP toolsets", "Enable
OAuth 2.1 on the MCP server", "Troubleshoot MCP server errors"; the AAP and MCP operator roles (read in the operator
pods) for what the documentation leaves out.

1. **AAP instance**: the AnsibleAutomationPlatform custom resource (CR) named in the variables, else the CR whose
   `status.URL` is this job's AAP URL (`aap_hostname`), else the only CR in the cluster.
2. **`spec.mcp`** on that CR (`disabled: false`, `allow_write_operations`, `extra_settings`, optional `route_host`,
   plus `openshift_automation_mcp_spec_overrides`), applied with `apply: true` so settings removed later are removed
   from the CR too. The AAP operator creates an `AnsibleMCPServer` named `<AAP CR name>-mcp` (the Ansible Lightspeed
   operator deploys it: deployment, service, route, ConfigMap).
3. **Recreate on change**: the AAP operator only copies `spec.mcp` into the `AnsibleMCPServer` when it creates it.
   When the running server's settings differ from the wanted ones, the role deletes the `AnsibleMCPServer` (the
   extend guide's procedure for changed permissions) before changing `spec.mcp`, so the reconcile that the change starts
   recreates it (deleting afterwards leaves it to the next reconcile, many minutes later). An AAP reconcile takes 8-10
   minutes and the operator may be in the middle of one, so a recreate takes up to about 20 minutes (30-minute wait).
4. Waits for the `AnsibleMCPServer` (`Successful` condition, `status.URL`) and its deployment, then checks
   `<URL>/api/v1/health`.
5. **OAuth application** (optional, with OAuth 2.1 on): authorization code grant, public or confidential client, the MCP
   clients' redirect URIs and PKCE required. A new confidential application's client ID and secret go to a Secret in
   the AAP namespace (AAP shows the secret only once). Re-runs update the redirect URIs, PKCE and description.

`state: absent` sets `spec.mcp.disabled: true`, deletes the `AnsibleMCPServer` (the AAP operator doesn't) and, with
`openshift_automation_mcp_oauth_app_create`, the OAuth application and its Secret.

Notes:
- **CA trust**: the AAP operator passes the AAP CR's `bundle_cacert_secret` on to the MCP server, so an AAP that already
  trusts the ingress CA needs nothing more. `IGNORE_CERTIFICATE_ERRORS` is for development only.
- **Extra settings are strings**: the MCP operator writes each value into a ConfigMap as `"{{ value }}"`, so a YAML
  boolean would become `True`; the role always writes lower-case strings (`true`/`false`).
- **Image**: the operator picks the MCP server image that matches the AAP version; nothing to set.
- **Token lifetime**: for OAuth 2.1 the extend guide recommends a shorter AAP access token lifetime
  (`OAUTH2_PROVIDER__ACCESS_TOKEN_EXPIRE_SECONDS`, for example 28800) so refresh tokens work; that is an AAP-wide
  setting and not changed here.
- Changing `spec.mcp` reconciles the whole AAP CR (normally a no-op for the other components).

## Requirements

- Collections: `redhat.openshift` and `kubernetes.core` (Red Hat certified). AAP gateway calls use `ansible.builtin.uri`.
- Credentials (in AAP, attach both): *OpenShift API (configuration as code)* (rights to patch the
  AnsibleAutomationPlatform CR and delete the AnsibleMCPServer) and *Red Hat Ansible Automation Platform*
  (`aap_hostname` for discovery; `aap_token` with rights to create OAuth applications in the organization, only for
  the OAuth application).

## Variables

See `defaults/main.yml`. Inputs normally supplied by the job template survey:

| Variable | Default | Notes |
|---|---|---|
| `openshift_automation_mcp_state` | `present` | `absent` disables and deletes the MCP server |
| `openshift_automation_mcp_platform_namespace` / `_platform_name` | `""` | Empty = discover the AnsibleAutomationPlatform CR |
| `openshift_automation_mcp_allow_write_operations` | `false` | `true` = tools that change AAP (still limited by each user's RBAC) |
| `openshift_automation_mcp_route_host` | `""` | Empty = `<AAP CR name>-mcp-<namespace>.<apps domain>` |
| `openshift_automation_mcp_oauth_enabled` / `_oauth_discovery_timeout` | `false` / `""` | `OAUTH2_ENABLED` / `OAUTH2_DISCOVERY_TIMEOUT` |
| `openshift_automation_mcp_ignore_certificate_errors` | `false` | `IGNORE_CERTIFICATE_ERRORS` (development only) |
| `openshift_automation_mcp_extra_settings` | `[]` | List of `{setting, value}` or `"SETTING=value,..."`; wins over the above |
| `openshift_automation_mcp_spec_overrides` | `{}` | Merged over the generated `spec.mcp` |
| `openshift_automation_mcp_oauth_app_create` | `false` | Create/update the AAP OAuth application (needs OAuth enabled) |
| `openshift_automation_mcp_oauth_app_name` / `_organization` | `Ansible MCP server` / `Default` | |
| `openshift_automation_mcp_oauth_app_client_type` | `public` | `confidential` stores the client secret in `_oauth_app_secret` |
| `openshift_automation_mcp_oauth_app_redirect_uris` | `http://localhost:6661/callback`, `http://127.0.0.1:6661/callback` | List or comma-separated |
| `openshift_automation_mcp_platform_url` / `_platform_token` | `""` | Empty = `aap_hostname` / `aap_token` |
| `openshift_automation_mcp_validate_certs` | `true` | This job verifies certificates |
| `openshift_automation_mcp_ca_certificate` | `""` | CA for AAP and the MCP route; empty = OpenShift ingress CA |

## Verify

The job reports the MCP server URL. Connect an MCP client to `<URL>/mcp` (all tools), `<URL>/mcp/discover` (toolset
discovery, fewer tokens) or `<URL>/mcp/<toolset>` (`job_management`, `inventory_management`, `system_monitoring`,
`user_management`, `security_compliance`, `platform_configuration`, `content_discovery`), with an AAP personal access
token (`Authorization: Bearer <token>`) or, with OAuth 2.1, for example
`claude mcp add --transport http --client-id <client ID> --callback-port 6661 aap-mcp <URL>/mcp`.
