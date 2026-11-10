# Ansible Automation Platform configuration (infra.aap_configuration)

One file per object type, using the collection's top-level variable names, for example:

| File | Variable | Object |
|---|---|---|
| `organizations.yml` | `aap_organizations` | gateway organizations |
| `teams.yml` | `aap_teams` | gateway teams |
| `credentials.yml` | `controller_credentials` | controller credentials |
| `projects.yml` | `controller_projects` | controller projects |
| `inventories.yml` | `controller_inventories` | controller inventories |
| `job_templates.yml` | `controller_templates` | job templates |
| `workflows.yml` | `controller_workflows` | workflow job templates |

Start from `playbooks/export_automation_platform.yml` output (`exports/automation_platform/`, git-ignored) rather than writing by hand.
Reference objects by **name**, never by numeric ID. Secrets stay as `{{ vaulted_* }}` variables supplied from a
vault file, never committed in plain text.

## Site settings and secrets

`00_settings.yml` holds **example values only**; the repo contains nothing site-specific. Copy the `site_*` settings
into a vars file **outside the repo**, change them, and pass it when applying (extra vars override the examples):

```bash
ansible-playbook playbooks/configure_automation_platform.yml -e @/path/to/site.yml [-e @vault.yml --ask-vault-pass]
```

| Setting | Example | Customize to |
|---|---|---|
| `site_organization` | `Default` | AAP organization that owns the objects |
| `site_project_scm_url` / `site_project_scm_branch` | `https://github.com/bhinson/ansible-config-as-code.git` / `main` | Your fork, if you change the code |
| `site_automation_platform_validate_certs` | `true` | `false` only if the AAP gateway certificate can't be verified |
| `site_execution_environment` | `Default execution environment` | An execution environment with `kubernetes.core` and python `kubernetes` |
| `site_automation_platform_gateway_host` | `aap.example.com` | Your AAP gateway hostname (survey default for the Automation Orchestrator (AO) workflow allowlist) |
| `site_automation_orchestrator_platform_integration_name` | `Ansible Automation Platform` | Name of your AO integration that launches AAP jobs |
| `site_machine_credential` | `Linux hosts` | Existing AAP machine credential (SSH user with sudo) for managed hosts |
| `site_cve_remediation_sample_hosts` | `[{name: rhel9.example.com}]` | RHEL hosts registered to Satellite for the CVE remediation inventory |
| `site_automation_orchestrator_storage_class` | `""` (cluster default) | Storage class for the AO PostgreSQL volume |

These only feed object definitions and survey defaults; the roles stay generic.
- Secret inputs are `{{ vaulted_* }}` variables, supplied at apply time from a vault-encrypted vars file
  (`ansible-playbook playbooks/configure_automation_platform.yml -e @vault.yml --ask-vault-pass`):
  `vaulted_openshift_api_url`, `vaulted_openshift_api_token`, `vaulted_openshift_api_ca_cert`, `vaulted_aap_url`,
  `vaulted_aap_token`.

## Automation Orchestrator job templates (`job_templates.yml`)

| Template | Playbook | Credentials | Survey highlights |
|---|---|---|---|
| Automation Orchestrator \| Install on OpenShift | `openshift_automation_orchestrator.yml` | Configuration as code - OpenShift API | namespace, channel, storage class, sizing, admin password, TLS verification |
| Automation Orchestrator \| Configure Ansible Automation Platform integration | `automation_orchestrator_configuration.yml` | Configuration as code - OpenShift API, Configuration as code - Ansible Automation Platform | integration token/user, single sign-on (SSO) on/off, OAuth org, identity provider TLS skip, CA, TLS verification |
| Automation Orchestrator \| Configure LLM provider integration | `automation_orchestrator_llm_integration.yml` | Configuration as code - OpenShift API | provider, base URL, API key, models, scope, TLS verification |
| Automation Orchestrator \| Configure CVE remediation workflow | `automation_orchestrator_cve_remediation.yml` | Configuration as code - OpenShift API | workflow name, integrations, LLM model, approvers, approval window, reboot, TLS verification |
| CVE remediation \| Assess hosts | `cve_remediation_assess.yml` | site machine credential | none (launched by the AO workflow with `cve_id` and a limit) |
| CVE remediation \| Apply fix | `cve_remediation_apply.yml` | site machine credential | none (launched by the AO workflow after approval) |

Order on a fresh cluster: apply `configure_automation_platform.yml` (credential type, credentials, inventory, project, templates),
launch **Install on OpenShift**, then **Configure Ansible Automation Platform integration**, then test SSO in a browser. Optionally launch **Configure LLM provider integration**, then **Configure CVE remediation workflow**.
