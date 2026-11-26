# Ansible Automation Platform configuration (infra.aap_configuration)

AAP objects as data for `infra.aap_configuration.dispatch`, split into **areas** so you apply only what you need.

| Folder | Applied | What it creates |
|---|---|---|
| `common/` | always | settings, the "OpenShift API (configuration as code)" credential type, the two "Configuration as code - …" credentials, the project, the localhost inventory with its `localhost` host, and the job template that applies this folder (its survey adds the optional OpenShift virtual machines inventory, role `openshift_automation_platform`) |
| `automation_orchestrator_install/` | if selected | job template "Automation Orchestrator \| Install on OpenShift" |
| `automation_orchestrator_integration/` | if selected | job template "Automation Orchestrator \| Configure Ansible Automation Platform integration" |
| `automation_orchestrator_llm_integration/` | if selected | job template "Automation Orchestrator \| Configure LLM provider integration" |
| `cve_remediation/` | if selected | inventory "CVE remediation - sample hosts", job templates "CVE remediation \| Assess hosts" / "\| Apply fix" and "Automation Orchestrator \| Configure CVE remediation workflow" |
| `automation_portal/` | if selected | job template "Automation portal \| Install on OpenShift" |
| `automation_developer_hub/` | if selected | job template "Developer Hub \| Install with the Ansible plug-ins on OpenShift" |
| `automation_mcp/` | if selected | job template "MCP server \| Install on OpenShift" |
| `automation_intelligent_assistant/` | if selected | job template "Intelligent assistant \| Enable on OpenShift" |
| `automation_x2ansible/` | if selected | job template "x2ansible \| Install on OpenShift" |
| `platform_management/` | opt-in | Galaxy credentials for the private automation hub mirrors and console.redhat.com, the organizations' Galaxy credential order, and the scheduled job "Automation hub \| Sync collection repositories" |

`site_configuration_areas` selects the areas (default: the eight use-case areas). Each area defines its objects under
`<dispatch variable>__<area>` (for example `controller_templates__cve_remediation`); `common/aggregate.yml` merges
whatever was loaded into the names the dispatch role reads, and `roles/openshift_automation_platform/tasks/load_configuration.yml` does the
loading for the configure, initialize and cleanup playbooks. Reference objects by **name**, never by ID.

Dependencies between areas: `cve_remediation` needs an Automation Orchestrator (AO) that already has an AAP integration
and an LLM provider integration (from the integration areas or set up by hand). AO itself can run anywhere: set
`site_cve_remediation_workflow_credentials: []` and give the AO URL, admin password and certificate authority (CA) in the
survey of "Configure CVE remediation workflow"; no OpenShift access is needed then. `automation_developer_hub` is independent too; it and
`automation_portal` share the Red Hat Developer Hub operator (role `openshift_automation_developer_hub_operator`, which adopts an
existing install). `automation_mcp` is independent as well (it changes `spec.mcp` of the AAP custom resource), and so is
`automation_intelligent_assistant` (`spec.lightspeed`). `automation_portal` is independent of AO:
it needs only an AAP for the portal to connect to (this job's AAP credential). `platform_management` changes AAP
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
| `site_configuration_areas` | the seven use-case areas | the areas you want; add `platform_management` to manage AAP itself |
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
| `site_automation_portal_catalog_organizations` | `Default` | AAP organizations synchronized into the portal catalog (automation_portal) |
| `site_automation_portal_job_template_labels` | `""` | labels a job template needs to appear in the portal (automation_portal) |
| `site_automation_portal_admin_users` | `""` (operator default) | portal administrators, `user:default/<AAP username>` (automation_portal) |
| `site_automation_portal_collections_enabled` / `_collection_repositories` | `"false"` / `""` | show the private automation hub's collections in the portal, and which hub repositories (automation_portal) |
| `site_developer_hub_operator_channel` | `fast` | Red Hat Developer Hub operator channel (`fast-<version>` = z-stream only) (automation_developer_hub) |
| `site_automation_developer_hub_admin_users` / `_super_users` | `""` | Developer Hub RBAC administrators / super users, `user:default/<AAP username>` (automation_developer_hub) |
| `site_automation_platform_operator_channel` | `stable-2.7` | AAP operator Subscription channel (survey default of the configure job template; a different channel on an existing Subscription fails unless allowed in the survey, because it upgrades AAP) |
| `site_openshift_virtual_machine_inventory` / `_namespaces` | `"false"` / `""` | survey defaults of the configure job template: create the inventory "Configuration as code - OpenShift virtual machines", and the namespaces it reads (empty = all) |
| `site_automation_x2ansible_github_client_id` / `_llm_url` / `_llm_model` | `""` | x2ansible survey defaults: GitHub OAuth app client ID, LLM base URL and LiteLLM model name (automation_x2ansible); secrets stay survey passwords |
| `site_automation_x2ansible_target_vm` / `_target_vm_activation_key` / `_target_vm_registration_organization` / `_target_vm_registration_server` | `"false"` / `""` | x2ansible target virtual machine and its registration (automation_x2ansible) |
| `site_resource_profile` | `default` | `small` = low CPU requests for the portal, Developer Hub, intelligent assistant and Automation Orchestrator (survey default of their install job templates; limits unchanged) |
| `site_automation_mcp_allow_write_operations` | `"false"` | `"true"` = MCP server tools may change AAP (survey default; automation_mcp) |
| `site_automation_intelligent_assistant_llm_provider_type` / `_llm_url` / `_llm_model` | `rhoai_vllm` / `""` / `""` | automation intelligent assistant LLM survey defaults (automation_intelligent_assistant); the token stays a survey password |
| `site_automation_orchestrator_llm_base_url` | `""` | LLM provider base URL (survey default; automation_orchestrator_llm_integration), so a rerun only needs the API key |
| `site_private_automation_hub_url` | `https://aap.example.com` | your private automation hub (platform_management) |
| `site_galaxy_credential_organizations` | `[{name: Default}]` | organizations whose Galaxy credential order is managed (platform_management) |
| `site_galaxy_credentials` | private hub ×4, console.redhat.com ×2, Ansible Galaxy | the ordered list; private hub only is fastest once the mirrors hold everything (platform_management) |
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
| Configuration as code \| Apply Ansible Automation Platform configuration | common | `openshift_automation_platform.yml` | Configuration as code - Ansible Automation Platform, OpenShift API (operator check, virtual machines inventory) |
| Automation Orchestrator \| Install on OpenShift | automation_orchestrator_install | `openshift_automation_orchestrator.yml` | Configuration as code - OpenShift API |
| Automation Orchestrator \| Configure Ansible Automation Platform integration | automation_orchestrator_integration | `automation_orchestrator_configuration.yml` | OpenShift API, Ansible Automation Platform |
| Automation Orchestrator \| Configure LLM provider integration | automation_orchestrator_llm_integration | `automation_orchestrator_llm_integration.yml` | OpenShift API |
| Automation Orchestrator \| Configure CVE remediation workflow | cve_remediation | `automation_orchestrator_cve_remediation.yml` | `site_cve_remediation_workflow_credentials` |
| CVE remediation \| Assess hosts / Apply fix | cve_remediation | `cve_remediation_assess.yml` / `_apply.yml` | site machine credential (launched by the AO workflow) |
| Automation portal \| Install on OpenShift | automation_portal | `openshift_automation_portal.yml` | OpenShift API, Ansible Automation Platform |
| Developer Hub \| Install with the Ansible plug-ins on OpenShift | automation_developer_hub | `openshift_automation_developer_hub.yml` | OpenShift API, Ansible Automation Platform |
| Automation hub \| Sync collection repositories (scheduled) | platform_management | `sync_automation_hub.yml` | Configuration as code - Ansible Automation Platform |

Order on a fresh cluster: run `playbooks/initialize_automation_platform.yml` (it launches the configure job template),
then **Install on OpenShift**, **Configure Ansible Automation Platform integration** (test single sign-on in a browser),
**Configure LLM provider integration**, and **Configure CVE remediation workflow**. The portal is separate:
**Automation portal \| Install on OpenShift** any time after initialization (open the reported URL and sign in with an
AAP account to verify). Developer Hub likewise: **Developer Hub \| Install with the Ansible plug-ins on OpenShift**.
