# ansible-config-as-code: configuration as code (generic roles + site config)

Ansible roles and playbooks that recreate OpenShift and Ansible Automation Platform (AAP) configuration. **Roles must stay generic** (no site hostnames,
storage classes, org names in defaults; discover from the cluster/credentials when possible).
**The repo holds no site-specific values at all**: `configs/automation_platform/00_settings.yml` has documented example
values (`example.com`); real values live in a site vars file outside the repo, passed with `-e @site.yml` when applying,
and reach roles through job template survey defaults. Before every commit, check for site names (hostnames, domains,
IP addresses, user/credential/organization names, storage classes) and secrets. Do not push unless asked.

## Runtime: Ansible Automation Platform first
All configuration as code is meant to run **through AAP**: a project pointing at this repo, one job template
per playbook, credentials attached to the job templates, and an execution environment (EE) that has the needed
collections/Python libs. Local runs (`scripts/env.sh` + `ansible-playbook --check`) are for testing only.

## Content source preference (always)
1. **Red Hat certified** collections from console.redhat.com Automation Hub (`ansible.platform`, `ansible.controller`,
   `ansible.eda`, `ansible.hub`, `redhat.openshift`, `kubernetes.core`, ...).
2. **Red Hat validated** content (`infra.aap_configuration`, `infra.*`).
3. Community collections / Galaxy roles only when 1 and 2 don't cover the need. Note why in the role README.

AAP project sync installs `collections/requirements.yml` with the organization's Galaxy credentials (console.redhat.com
certified/validated, private hub, Galaxy, in that order), so the repo holds no galaxy servers or hub tokens.
`collections/requirements.yml` groups entries in preference order.

## Secrets
- Nothing secret is committed. In AAP, secrets come from AAP credentials injected into the job.
- Local testing: `scripts/env.sh` (source it) exports `aap.server/token` and `openshift.server/token` from a secrets file
  outside the repo (`CONFIGURATION_AS_CODE_SECRETS_FILE`, optional CA bundles via `CONFIGURATION_AS_CODE_*_CA_FILE`; see
  the script header) and builds a CA bundle in `.ansible/` (ignored).
- Generated passwords live only in cluster Secrets (created once, never rotated by re-runs) or in a vault file.
- Exported AAP secrets appear as `{{ vaulted_* }}` placeholders; their values go in a git-ignored/vaulted vars file.

## Layout
- `playbooks/` – entry points (`openshift_*` for OpenShift, `configure_automation_platform.yml` / `export_automation_platform.yml` for AAP).
- `roles/<platform>_<thing>/` – our roles: `openshift_automation_orchestrator` (install Automation Orchestrator (AO)), `automation_orchestrator_configuration` (connect AO to AAP),
  `automation_orchestrator_llm_integration` (connect AO to a large language model (LLM) provider),
  `automation_orchestrator_cve_remediation` (AO CVE remediation workflow; its job templates run
  `playbooks/cve_remediation_assess.yml` / `cve_remediation_apply.yml` on managed hosts). One role per concern, each with
  its own job template and survey.
- User inputs: AAP job template **surveys** (`configs/automation_platform/job_templates.yml`). Survey answers are strings, so roles accept
  comma-separated lists and `"true"`/`"false"`, and treat `""` as unset (`default(x, true)`).
- `configs/automation_platform/` – AAP objects as data for `infra.aap_configuration.dispatch`.
- `inventory/` – localhost-only inventory; connection vars read from the environment.

## Conventions (from infra.aap_configuration / aap_configuration_extended)
- `.yml` extension; YAML documents start with `---` and end with `...`; 2-space indent; `{{ var }}` with spaces.
- Role variables prefixed with the role name (`openshift_automation_orchestrator_*`); internal/loop vars prefixed `__`.
- Task names prefixed with the file stem: `Postgres | Wait for ...`.
- Always FQCNs (`kubernetes.core.k8s`, `ansible.builtin.include_vars`).
- AAP 2.5+: `aap_hostname` is the **platform gateway** URL; prefer `aap_token` over username/password.
- Variable names for AAP objects follow the dispatch role (`aap_organizations`, `aap_teams`, `aap_user_accounts`,
  `controller_projects`, `controller_templates`, `controller_workflows`, `eda_projects`, `hub_namespaces`, ...).
- **Names, never IDs** for object references and selectors.
- **No self-referential Jinja in task `vars:`** (`key: "{{ key | default([]) }}"` loops forever; see upstream
  [ansible-jinja-no-self-ref](https://github.com/redhat-cop/aap_configuration_extended/blob/devel/skills/ansible-jinja-no-self-ref/SKILL.md)). Local check (perl, since macOS `grep` here is
  ugrep without back-references) must print nothing:
  `perl -ne 'print "$ARGV:$.: $_" if /^\s+([a-z_]+): "\{\{ \1 \|/; close ARGV if eof' $(find roles playbooks -name '*.yml')`
- **TLS verification is always configurable**: each role has a `<role>_validate_certs` variable (default `true`) for
  the job's own calls (`module_defaults` for `group/kubernetes.core.k8s`, `validate_certs` on every `uri`), plus a
  separate variable for what AO itself verifies (`insecure_skip_tls_verify` on integrations). Expose them in the
  survey; survey answers are strings, so always apply `| bool`. Prefer passing a CA bundle over disabling checks.
- Idempotent re-runs: secrets created only when missing; `kubernetes.core.k8s` with `apply: true`.
- Lint target: `ansible-lint` profile `production`, `yamllint`.

## Running
- **Bootstrap:** `playbooks/seed_automation_platform.yml` (ansible-core only, `ansible.builtin.uri` against the AAP
  REST API) creates the credential type, the two credentials, the project, the localhost inventory and the
  "Configuration as code | Apply Ansible Automation Platform configuration" job template, then launches it. Never assume
  certified collections on the CLI; AAP installs them during project sync. `--check` prints the plan and stops.
- **In AAP (normal):** project = this repo; job template per playbook (`playbooks/*.yml`, inventory with localhost);
  credentials: **"OpenShift API (configuration as code)"** (custom type defined in `configs/automation_platform/credential_types.yml`) for `openshift_*`
  playbooks, "Red Hat Ansible Automation Platform" for `configure_automation_platform.yml` / `export_automation_platform.yml`.
  - The managed "OpenShift or Kubernetes API Bearer Token" type has **no injectors** (container groups only), so it
    gives playbooks nothing, hence the custom type with host, token and CA.
  - The AAP credential injects `aap_hostname`/`aap_token`/`aap_validate_certs` as extra vars plus `AAP_*` environment variables.
  - The EE must provide the collections' Python deps (`kubernetes` for kubernetes.core); check the
    EE before the first run.
  - Credential type injectors in `configs/automation_platform/` must be tagged `!unsafe` so Ansible doesn't render them on load.
- **Locally (testing):**
  ```bash
  export CONFIGURATION_AS_CODE_SECRETS_FILE=/path/outside/repo/secrets.yml   # see scripts/env.sh header
  source scripts/env.sh
  python3 -m pip install -r requirements.txt     # in a venv
  ansible-galaxy collection install -r collections/requirements.yml   # needs a hub source; AAP normally does this
  ansible-playbook playbooks/openshift_automation_orchestrator.yml --check
  ```

## Skills
Layout follows redhat-cop/aap_configuration_extended: tool-agnostic `skills/<name>/SKILL.md` (folded `description: >-`)
indexed in `AGENTS.md`; `.claude/skills` is a symlink to `skills/`. Skills in this repo must stay generic (no site
hostnames or names; use `example.com`). Add new skills to `AGENTS.md` under the right group.
**Don't copy upstream redhat-cop skills**: link them (in `AGENTS.md`/here) so they can't drift; only add a local skill
for what's specific to this repo.
- `skills/automation-platform-config-export` – capture the live AAP config into `configs/automation_platform/` with filetree_create.
- Upstream (linked): [ansible-jinja-no-self-ref](https://github.com/redhat-cop/aap_configuration_extended/blob/devel/skills/ansible-jinja-no-self-ref/SKILL.md),
  [export-jt-related-pre-pro](https://github.com/redhat-cop/aap_configuration_extended/blob/devel/skills/export-jt-related-pre-pro/SKILL.md).
- AO only: `skills/automation-orchestrator-install-openshift` (install/size/troubleshoot AO), `skills/automation-orchestrator-platform-integration` (AAP integration + single sign-on),
  `skills/automation-orchestrator-llm-integration` (LLM provider integration), `skills/automation-orchestrator-cve-remediation`
  (CVE remediation workflow, AO workflow definitions).

## Documentation style
- Docs and comments: spell a term out on first use with the abbreviation in parentheses, e.g. "Ansible Automation
  Platform (AAP)", then use the abbreviation for the rest of that document. A term used only once stays spelled out.
- Variable names, role names, file names and other identifiers: long names, no abbreviations
  (`automation_orchestrator_*`, `openshift_*`), except names defined by other projects (`aap_hostname`, `infra.aap_*`).
- Strings shown on their own in the AAP UI (task names, survey questions, object descriptions): spelled out.
