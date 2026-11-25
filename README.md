# ansible-config-as-code

Configuration as code for OpenShift clusters running Ansible Automation Platform (AAP). Roles are generic; all
site-specific values go in a vars file **outside this repo** that overrides the example values in
`configs/common/00_settings.yml` (see `configs/README.md`, "Site settings"). Configuration is split into **areas**
(one per use case, plus an opt-in `platform_management` area for AAP itself); `site_configuration_areas` picks them.

Modeled on the Red Hat Communities of Practice collections
[infra.aap_configuration](https://github.com/redhat-cop/infra.aap_configuration) and
[aap_configuration_extended](https://github.com/redhat-cop/aap_configuration_extended), and built on
Red Hat certified collections first, Red Hat validated content second, and community content only when needed.

## What's here

| Path | Purpose |
|---|---|
| `playbooks/openshift_automation_orchestrator.yml` | Install Red Hat Automation Orchestrator (AO) on OpenShift (operator, PostgreSQL, instance) |
| `playbooks/openshift_automation_platform.yml` | Apply `configs/common` and the selected areas via `infra.aap_configuration.dispatch` (`configure_automation_platform.yml` is an alias) |
| `roles/openshift_automation_platform/` | That configuration run: AAP operator check, `configs/`, optional OpenShift Virtualization virtual machines inventory (generic) |
| `roles/openshift_automation_platform_operator/` | Install or adopt the AAP operator (included by the configuration run; an existing Subscription's channel changes only on request) |
| `playbooks/sync_automation_hub.yml` | Sync private automation hub repositories (scheduled; area platform_management) |
| `playbooks/export_automation_platform.yml` | Export the live AAP configuration to YAML (`infra.aap_configuration_extended.filetree_create`) |
| `playbooks/automation_orchestrator_configuration.yml` | Connect AO to AAP (allowlists, integration, single sign-on) |
| `roles/openshift_automation_orchestrator/` | Install AO on OpenShift (generic) |
| `roles/automation_orchestrator_configuration/` | Configure AO for AAP (generic) |
| `playbooks/automation_orchestrator_llm_integration.yml` | Connect AO to an OpenAI API-compatible large language model provider |
| `roles/automation_orchestrator_llm_integration/` | Configure the AO LLM provider integration (generic) |
| `playbooks/automation_orchestrator_cve_remediation.yml` | Add the AO CVE remediation workflow (CVE lookup, LLM triage, approval, Satellite fix) |
| `roles/automation_orchestrator_cve_remediation/` | Build and publish that workflow (generic) |
| `playbooks/openshift_automation_portal.yml` | Install Ansible automation portal on OpenShift (operator, AAP OAuth application, catalog token) |
| `roles/openshift_automation_portal/` | Install and connect Ansible automation portal (generic; independent of AO) |
| `playbooks/openshift_automation_mcp.yml` | MCP server for AAP on an operator-based AAP on OpenShift (optional OAuth 2.1 application) |
| `roles/openshift_automation_mcp/` | Deploy and configure the MCP server through the AAP operator (generic) |
| `playbooks/openshift_automation_intelligent_assistant.yml` | Automation intelligent assistant (Lightspeed chat) on an operator-based AAP on OpenShift, LLM settings from the survey |
| `roles/openshift_automation_intelligent_assistant/` | Chatbot configuration Secret + `spec.lightspeed` through the AAP operator (generic) |
| `playbooks/openshift_automation_developer_hub.yml` | Red Hat Developer Hub with the Ansible plug-ins on OpenShift (AAP sign-in, plug-in token) |
| `roles/openshift_automation_developer_hub/` | Deploy and connect Developer Hub with the Ansible plug-ins (generic) |
| `roles/openshift_developer_hub_operator/` | Install or adopt the Red Hat Developer Hub operator (shared by the Developer Hub and portal roles) |
| `playbooks/cve_remediation_assess.yml`, `cve_remediation_apply.yml` | Host playbooks the workflow launches (assess read-only; apply after approval) |
| `configs/` | AAP configuration data by area (see `configs/README.md`) |
| `playbooks/initialize_automation_platform.yml` | Initialize AAP (ansible-core only) and launch the configure job template |
| `playbooks/cleanup_automation_platform.yml` | Remove every AAP object this repo creates (job history is kept) |
| `scripts/env.sh` | Loads tokens and CA bundle into the environment (source it) |
| `skills/`, `AGENTS.md` | Agent skills (redhat-cop layout; upstream redhat-cop skills are linked from `AGENTS.md`, not copied) |

## Prerequisites

- AAP 2.5 or later. The organization that will own the objects needs a Galaxy credential for console.redhat.com
  Automation Hub (certified and validated content): AAP installs `collections/requirements.yml` with it during project
  sync. The machine you deploy from needs **no** certified collections.
- An AAP administrator token, and for the OpenShift roles a cluster API URL, token and CA bundle.
- An existing machine credential for managed hosts (CVE remediation), named in your site settings.

## Getting started

Everything runs in AAP. A small initialization playbook (ansible-core only, plain REST calls) creates what AAP needs to apply the
rest of this repo, then launches it.

1. Copy the `site_*` settings from `configs/common/00_settings.yml` into a vars file outside this repo and change them,
   including `site_configuration_areas` (see `configs/README.md`, "Site settings").
2. Initialize AAP:

   ```bash
   export AAP_HOSTNAME=https://aap.example.com AAP_TOKEN=...          # or a secrets file with scripts/env.sh
   export K8S_AUTH_HOST=https://api.cluster.example.com:6443 K8S_AUTH_API_KEY=... K8S_AUTH_SSL_CA_CERT=/path/to/api-ca.pem
   export AAP_CA_FILE=/path/to/ingress-ca.pem                          # only if the AAP certificate isn't publicly trusted
   ansible-playbook playbooks/initialize_automation_platform.yml -e @/path/to/site.yml --check   # dry run: shows the plan
   ansible-playbook playbooks/initialize_automation_platform.yml -e @/path/to/site.yml
   ```

   It creates, if missing, the credential type "OpenShift API (configuration as code)", the credentials
   "Configuration as code - OpenShift API" and "Configuration as code - Ansible Automation Platform", the project,
   the inventory "Configuration as code - localhost", and the job template
   **"Configuration as code | Apply Ansible Automation Platform configuration"** (your site values become its extra vars),
   then launches that job template, which creates every other object in `configs/common` and the selected areas.
   Its survey can also create the inventory "Configuration as code - OpenShift virtual machines" (AAP's OpenShift
   Virtualization inventory source, synced on launch; attach it to job templates yourself).
3. Afterwards, change the configuration in git and re-launch that job template. Run the Automation Orchestrator job
   templates in the order listed in `configs/README.md`, "Automation portal | Install on OpenShift" for the portal, "Developer Hub | Install with the Ansible plug-ins on
   OpenShift" for Developer Hub, and "MCP server | Install on OpenShift" for the MCP server.

**Removing it again:** `ansible-playbook playbooks/cleanup_automation_platform.yml -e @/path/to/site.yml [--check]`
deletes, by exact name from `configs/common` and the selected areas (never `platform_management`) and only in the site
organization, the job templates,
inventory sources, inventories (with their hosts), the project, the credentials and the custom credential type, in that
order. Playbook run history is kept (AAP itself removes project and inventory sync records along with their project or
source); nothing else in AAP is touched. `--check` lists what it would delete. Objects that
Automation Orchestrator, automation portal and MCP server roles create (in AO, OpenShift or the AAP gateway) are not removed.

**Without the initialization playbook** (AAP UI): create the same objects by hand: the credential type (inputs and injectors from
`configs/common/credential_types.yml`), the two credentials, a project for this repo, an inventory with one
host `localhost` (variable `ansible_connection: local`), and a job template for `playbooks/openshift_automation_platform.yml`
with the "Configuration as code - Ansible Automation Platform" credential and your site values as extra vars. Launch it.

Local test runs (`--check`) need a Python 3.12 virtualenv with `requirements.txt` and `requirements-test.txt` (ansible-core
pinned to the version in AAP's execution environment, 2.16), the collections, and the tokens from `scripts/env.sh`.

## Secrets

No credentials are stored in this repository. In AAP they come from credentials attached to job templates; locally from `scripts/env.sh`. See `.gitignore`.
