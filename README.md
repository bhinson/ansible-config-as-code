# ansible-config-as-code

Configuration as code for OpenShift clusters running Ansible Automation Platform (AAP). Roles are generic; all
site-specific values go in a vars file **outside this repo** that overrides the example values in
`configs/automation_platform/00_settings.yml` (see `configs/automation_platform/README.md`, "Site settings").

Modeled on the Red Hat Communities of Practice collections
[infra.aap_configuration](https://github.com/redhat-cop/infra.aap_configuration) and
[aap_configuration_extended](https://github.com/redhat-cop/aap_configuration_extended), and built on
Red Hat certified collections first, Red Hat validated content second, and community content only when needed.

## What's here

| Path | Purpose |
|---|---|
| `playbooks/openshift_automation_orchestrator.yml` | Install Red Hat Automation Orchestrator (AO) on OpenShift (operator, PostgreSQL, instance) |
| `playbooks/configure_automation_platform.yml` | Apply AAP objects from `configs/automation_platform/` via `infra.aap_configuration.dispatch` |
| `playbooks/export_automation_platform.yml` | Export the live AAP configuration to YAML (`infra.aap_configuration_extended.filetree_create`) |
| `playbooks/automation_orchestrator_configuration.yml` | Connect AO to AAP (allowlists, integration, single sign-on) |
| `roles/openshift_automation_orchestrator/` | Install AO on OpenShift (generic) |
| `roles/automation_orchestrator_configuration/` | Configure AO for AAP (generic) |
| `playbooks/automation_orchestrator_llm_integration.yml` | Connect AO to an OpenAI API-compatible large language model provider |
| `roles/automation_orchestrator_llm_integration/` | Configure the AO LLM provider integration (generic) |
| `playbooks/automation_orchestrator_cve_remediation.yml` | Add the AO CVE remediation workflow (CVE lookup, LLM triage, approval, Satellite fix) |
| `roles/automation_orchestrator_cve_remediation/` | Build and publish that workflow (generic) |
| `playbooks/cve_remediation_assess.yml`, `cve_remediation_apply.yml` | Host playbooks the workflow launches (assess read-only; apply after approval) |
| `configs/automation_platform/` | AAP configuration data: credential type, credentials, inventory, project, job templates with surveys |
| `scripts/env.sh` | Loads tokens and CA bundle into the environment (source it) |
| `skills/`, `AGENTS.md` | Agent skills (redhat-cop layout; upstream redhat-cop skills are linked from `AGENTS.md`, not copied) |

## Prerequisites

Runs as an **AAP project**: project sync installs `collections/requirements.yml` with the organization's
Galaxy credentials, and job templates supply the OpenShift and AAP credentials.

For local testing: ansible-core 2.16+, Python packages from `requirements.txt` (virtualenv), and the OpenShift /
AAP tokens exported by `scripts/env.sh`.

## Usage

In AAP: create a project from this repo and a job template per playbook (see `CLAUDE.md`).

Locally (testing):

```bash
source scripts/env.sh                      # reads a local secrets file, prints only which vars are set
ansible-playbook playbooks/openshift_automation_orchestrator.yml --check
```

## Secrets

No credentials are stored in this repository. In AAP they come from credentials attached to job templates; locally from `scripts/env.sh`. See `.gitignore`.
