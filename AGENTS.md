# Agent instructions

Repo conventions, layout and how to run things: [CLAUDE.md](CLAUDE.md). Skills live in [skills/](skills/) as
`skills/<name>/SKILL.md` (tool-agnostic; same layout works for Claude Code, Cursor, Codex, etc.;
`.claude/skills` is a symlink to `skills/`). Read a skill only when its task comes up.

## Ansible Automation Platform
- Exporting live Ansible Automation Platform (AAP) objects into `configs/automation_platform/` (back up as code, migrate, start managing existing objects): follow
  [skills/automation-platform-config-export/SKILL.md](skills/automation-platform-config-export/SKILL.md).
- Single job template / workflow plus related objects between environments (pre-production to production): upstream
  [export-jt-related-pre-pro](https://github.com/redhat-cop/aap_configuration_extended/blob/devel/skills/export-jt-related-pre-pro/SKILL.md).

Upstream skills from [redhat-cop/aap_configuration_extended](https://github.com/redhat-cop/aap_configuration_extended/tree/devel/skills)
are linked, never copied, so they stay current.

## Automation Orchestrator (only when working on it)
- Installing Automation Orchestrator (AO) on OpenShift, `roles/openshift_automation_orchestrator`, PostgreSQL/Temporal problems, connection sizing:
  follow [skills/automation-orchestrator-install-openshift/SKILL.md](skills/automation-orchestrator-install-openshift/SKILL.md).
- Connecting AO to AAP, `roles/automation_orchestrator_configuration`, integration and single sign-on failures, AO REST API calls: follow
  [skills/automation-orchestrator-platform-integration/SKILL.md](skills/automation-orchestrator-platform-integration/SKILL.md).
- Connecting AO to a large language model (LLM) provider, `roles/automation_orchestrator_llm_integration`, model
  discovery and LLM integration failures: follow
  [skills/automation-orchestrator-llm-integration/SKILL.md](skills/automation-orchestrator-llm-integration/SKILL.md).
- AO CVE remediation workflow (`roles/automation_orchestrator_cve_remediation`, playbooks `cve_remediation_*.yml`),
  AO workflow definitions and run debugging: follow
  [skills/automation-orchestrator-cve-remediation/SKILL.md](skills/automation-orchestrator-cve-remediation/SKILL.md).
- Any AO API work: the OpenAPI specification at `https://<AO host>/api_docs/v1/openapi.json` is the documented contract.

## Always
- **Never** write self-referential Jinja under task `vars:` (`key: "{{ key | default([]) }}"`); it causes recursive
  template loops. Follow upstream [ansible-jinja-no-self-ref](https://github.com/redhat-cop/aap_configuration_extended/blob/devel/skills/ansible-jinja-no-self-ref/SKILL.md) and run the
  perl check in [CLAUDE.md](CLAUDE.md) (Conventions).
- **Names, never IDs** for object references, selectors and extra vars.
- Roles stay generic: no site hostnames, storage classes or org names in role defaults or skills. Site values go only
  in `configs/automation_platform/00_settings.yml`.
- Nothing secret is committed (see `.gitignore`).
