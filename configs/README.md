# Ansible Automation Platform configuration (infra.aap_configuration)

AAP objects as data for `infra.aap_configuration.dispatch`, split into **areas** so you apply only what you need.

| Folder | Applied | What it creates |
|---|---|---|
| `common/` | always | settings, the "OpenShift API (configuration as code)" credential type, the two "Configuration as code - …" credentials, the project, the localhost inventory, and the job template that applies this folder |
| `automation_orchestrator_install/` | if selected | job template "Automation Orchestrator \| Install on OpenShift" |
| `automation_orchestrator_integration/` | if selected | job template "Automation Orchestrator \| Configure Ansible Automation Platform integration" |
| `automation_orchestrator_llm_integration/` | if selected | job template "Automation Orchestrator \| Configure LLM provider integration" |
| `cve_remediation/` | if selected | inventory "CVE remediation - sample hosts", job templates "CVE remediation \| Assess hosts" / "\| Apply fix" and "Automation Orchestrator \| Configure CVE remediation workflow" |
| `platform_management/` | opt-in | Galaxy credentials for the private automation hub mirrors and console.redhat.com, the organizations' Galaxy credential order, and the scheduled job "Automation hub \| Sync collection repositories" |

`site_configuration_areas` selects the areas (default: the four use-case areas). Each area defines its objects under
`<dispatch variable>__<area>` (for example `controller_templates__cve_remediation`); `common/aggregate.yml` merges
whatever was loaded into the names the dispatch role reads, and `playbooks/tasks/load_configuration.yml` does the
loading for the configure, initialize and cleanup playbooks. Reference objects by **name**, never by ID.

Dependencies between areas: `cve_remediation` needs an Automation Orchestrator (AO) that already has an AAP integration
and an LLM provider integration (from the integration areas or set up by hand). AO itself can run anywhere: set
`site_cve_remediation_workflow_credentials: []` and give the AO URL, admin password and certificate authority (CA) in the
survey of "Configure CVE remediation workflow"; no OpenShift access is needed then. `platform_management` changes AAP
itself, needs an AAP administrator token, and is never removed by the cleanup playbook (it adopts existing objects).

## Site settings and secrets

`common/00_settings.yml` holds **example values** (the project URL is this repo); the repo contains nothing
site-specific. Copy the `site_*` settings into a vars file **outside the repo**, change them, and pass it when applying
(extra vars override the examples):

```bash
ansible-playbook playbooks/initialize_automation_platform.yml -e @/path/to/site.yml
```

| Setting | Example | Customize to |
|---|---|---|
| `site_configuration_areas` | the four use-case areas | the areas you want; add `platform_management` to manage AAP itself |
| `site_organization` | `Default` | AAP organization that owns the objects |
| `site_project_scm_url` / `site_project_scm_branch` | this repo / `main` | your fork, if you change the code |
| `site_automation_platform_validate_certs` | `true` | `false` only if jobs can't verify the AAP gateway certificate |
| `site_execution_environment` | `Default execution environment` | an EE with the collections' Python dependencies (`kubernetes`) |
| `site_automation_platform_gateway_host` | `aap.example.com` | your AAP gateway hostname (AO workflow allowlist survey default) |
| `site_automation_orchestrator_platform_integration_name` | `Ansible Automation Platform` | your AO integration that launches AAP jobs |
| `site_machine_credential` | `Linux hosts` | existing AAP machine credential (SSH user with sudo) for managed hosts |
| `site_cve_remediation_workflow_credentials` | OpenShift API credential | `[]` when AO runs elsewhere (give its URL, password and CA in the survey) |
| `site_cve_remediation_sample_hosts` | `[{name: rhel9.example.com}]` | RHEL hosts registered to Satellite for the CVE remediation inventory |
| `site_automation_orchestrator_storage_class` | `""` (cluster default) | storage class for the AO PostgreSQL volume |
| `site_private_automation_hub_url` | `https://aap.example.com` | your private automation hub (platform_management) |
| `site_galaxy_credential_organizations` | `[{name: Default}]` | organizations whose Galaxy credential order is managed (platform_management) |
| `site_automation_hub_sync_repositories` | `[rh-certified, validated, community]` | hub repositories the scheduled job syncs (platform_management) |
| `site_automation_hub_sync_rrule` | daily 02:00 UTC | when it runs; an RRULE with DTSTART (time zone in TZID) (platform_management) |

Secret inputs are `{{ vaulted_* }}` variables, supplied only when you want to set or rotate them, from a
vault-encrypted vars file (`-e @vault.yml --ask-vault-pass`): `vaulted_openshift_api_url`, `vaulted_openshift_api_token`,
`vaulted_openshift_api_ca_cert`, `vaulted_aap_url`, `vaulted_aap_token` (the initialize playbook sets these once), and for
platform_management `vaulted_private_automation_hub_token` (an AAP token; the private hub rejects console.redhat.com
tokens) and `vaulted_red_hat_automation_hub_token` (console.redhat.com offline token).

## Job templates

| Template | Area | Playbook | Credentials |
|---|---|---|---|
| Configuration as code \| Apply Ansible Automation Platform configuration | common | `configure_automation_platform.yml` | Configuration as code - Ansible Automation Platform |
| Automation Orchestrator \| Install on OpenShift | automation_orchestrator_install | `openshift_automation_orchestrator.yml` | Configuration as code - OpenShift API |
| Automation Orchestrator \| Configure Ansible Automation Platform integration | automation_orchestrator_integration | `automation_orchestrator_configuration.yml` | OpenShift API, Ansible Automation Platform |
| Automation Orchestrator \| Configure LLM provider integration | automation_orchestrator_llm_integration | `automation_orchestrator_llm_integration.yml` | OpenShift API |
| Automation Orchestrator \| Configure CVE remediation workflow | cve_remediation | `automation_orchestrator_cve_remediation.yml` | `site_cve_remediation_workflow_credentials` |
| CVE remediation \| Assess hosts / Apply fix | cve_remediation | `cve_remediation_assess.yml` / `_apply.yml` | site machine credential (launched by the AO workflow) |
| Automation hub \| Sync collection repositories (scheduled) | platform_management | `sync_automation_hub.yml` | Configuration as code - Ansible Automation Platform |

Order on a fresh cluster: run `playbooks/initialize_automation_platform.yml` (it launches the configure job template),
then **Install on OpenShift**, **Configure Ansible Automation Platform integration** (test single sign-on in a browser),
**Configure LLM provider integration**, and **Configure CVE remediation workflow**.
