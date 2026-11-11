---
name: automation-platform-config-export
description: >-
  Capture the live Ansible Automation Platform (AAP) configuration as code with
  infra.aap_configuration_extended.filetree_create, then curate it into
  an area under configs/ for infra.aap_configuration.dispatch. Use when asked to export,
  back up as code, migrate, or start managing existing AAP objects in this repo.
---

# Export live Ansible Automation Platform config into configs/

Repo-specific wrapper around infra.aap_configuration_extended.filetree_create (see its README). Generic upstream
procedures are linked, not copied, so they can't drift from the collection.

## Rules
- **Names, never IDs.** Keep `omit_id: true`; select with `organization_filter: <org name>`, `job_template_name`, etc.
- Secrets export as `{{ vaulted_<type>_<name>_<field> }}` placeholders (`secrets_as_variables: true`), and the role
  writes `env_variables.yml` with every placeholder set to `CHANGE_ME`. That file holds real secrets once filled in:
  keep it out of git (it's in `.gitignore`) or encrypt it with `ansible-vault`.
- Export output goes to `exports/automation_platform/` (git-ignored). Only curated files move into an area folder under `configs/`, with variables renamed to `<dispatch variable>__<area>` (see `configs/README.md`).
- Reading or exporting is safe; **applying** (`configure_automation_platform.yml`) writes to AAP, so confirm with the user first
  and run with `--check` before a real run.

## Steps
Normally run as an AAP job template on `playbooks/export_automation_platform.yml` with a "Red Hat Ansible Automation Platform"
credential, then collect the output (for example, have the job push to a branch, or run locally for the first capture).
Locally:
1. `source scripts/env.sh` (needs `aap.server`/`aap.token` in the secrets file it reads; see the script header).
2. Collections must be installed locally (AAP does this itself during project sync).
3. Export everything, or one org:
   `ansible-playbook playbooks/export_automation_platform.yml` or `... -e organization_filter=Default`.
   - Only some object types: `-e '{"input_tag": ["projects", "job_templates"]}'` (valid tags are in the role's `vars/valid_tags`).
   - Single job template or workflow plus everything it depends on (pre-production to production migration): follow upstream
     [export-jt-related-pre-pro](https://github.com/redhat-cop/aap_configuration_extended/blob/devel/skills/export-jt-related-pre-pro/SKILL.md), writing output under `exports/automation_platform/`.
4. Review `exports/automation_platform/`: drop defaults/noise, check names, then copy files into an area folder under `configs/`, renaming the
   dispatch variable names to `<name>__<area>` (`controller_projects`, `controller_templates`, `aap_organizations`, ...).
5. Validate with no changes expected: `ansible-playbook playbooks/configure_automation_platform.yml --check`. Anything reported as
   changed is drift between code and AAP; fix the code or confirm the change with the user.

## Gotchas
- With `flatten_output: true` you get one file per object type (simplest to curate into an area). Without it, files are
  split by organization and object (better for very large installs). `infra.aap_configuration_extended.filetree_read`
  can load either layout (`controller_configuration_filetree_read_layout: create|flatten|hierarchical`).
- Built-in objects (Default org, Demo items, managed credential types) come out in the export. Don't manage them
  unless you mean to.
