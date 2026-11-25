# openshift_automation_platform

Applies this repo's **Ansible Automation Platform (AAP) configuration as code** and optionally adds an **inventory of
the OpenShift Virtualization virtual machines**. Job template: "Configuration as code | Apply Ansible Automation
Platform configuration" (playbook `playbooks/openshift_automation_platform.yml`; `configure_automation_platform.yml`
is a kept alias).

0. **Operator**: includes `openshift_ansible_platform_operator`, which adopts the existing AAP operator Subscription (or
   installs it) and waits for its ClusterServiceVersion; on reruns a few API reads. Survey: channel (an existing
   Subscription on another channel fails the run unless "Allow an operator channel change" is true, because that upgrades
   AAP). `openshift_automation_platform_operator: false` skips it.
1. **Configuration**: loads `configs/common` plus the areas in `site_configuration_areas` (`tasks/load_configuration.yml`,
   also used by the initialize and cleanup playbooks through `include_role` `tasks_from`) and applies them with
   `infra.aap_configuration.dispatch`. `configs/common` includes the "Configuration as code - localhost" inventory and its
   `localhost` host (local connection, `ansible_python_interpreter: {{ ansible_playbook_python }}`), so jobs no longer
   wait for an inventory sync from the repo.
2. **OpenShift virtual machines inventory** (survey "Create the OpenShift virtual machines inventory"): uses AAP's built-in
   **OpenShift Virtualization** inventory source (`source: openshift_virtualization`, the `kubevirt.core.kubevirt`
   plugin shipped in the supported execution environment) with **update on launch**, overwrite of hosts and
   variables, and no cache timeout. Hosts whose `vm_printable_status` isn't `Running` (stopped, starting, migrating) are
   synced as **disabled** (`enabled_var` / `enabled_value`), so jobs skip them without a host filter. It isn't attached to any job template; pick it on a job template by hand.
   - The source needs an *OpenShift or Kubernetes API Bearer Token* credential. Instead of this job's (usually
     cluster-admin) OpenShift API token, the role creates a **read-only service account** with a long-lived token Secret
     (namespace `automation-platform-inventory`) and a ClusterRole that can only read projects/namespaces, services,
     virtual machines, virtual machine instances and the cluster DNS config. With namespaces listed it gets a
     RoleBinding in each of them; without, a ClusterRoleBinding. All carry the labels
     `app.kubernetes.io/component=virtual-machine-inventory` and `app.kubernetes.io/managed-by=ansible-config-as-code`;
     bindings no longer wanted (namespaces removed from the list, or the cluster-wide one once namespaces are listed)
     are deleted. A namespace the role created is annotated `ansible-config-as-code/created-by: openshift_automation_platform`.
   - The credential gets the API URL and certificate authority (CA) from this job's *OpenShift API (configuration as
     code)* credential (`K8S_AUTH_HOST`, `K8S_AUTH_SSL_CA_CERT`), or from the `_api_url` / `_api_ca_certificate`
     variables. Its secrets are written when it's created; set `_update_secrets: true` to rewrite them.
   - Source variables: `connections: [{namespaces: [...]}]` when namespaces are listed, merged with
     `openshift_automation_platform_virtual_machine_inventory_source_variables` (any plugin option, for example
     `label_selector` or `network_name`). Host names are the plugin's default, `<namespace>-<name>`.

Answering `false` later leaves the inventory in place. The cleanup playbook removes the inventory, source and credential
with `configs/common`, and (with `K8S_AUTH_*` set) the labelled bindings and ClusterRole plus the namespace if the role
created it, otherwise only the service account and its token Secret. The AAP operator is never removed.

## Requirements

- Collections: `infra.aap_configuration` (Red Hat validated) with `ansible.controller` / `ansible.platform`;
  `redhat.openshift` and `kubernetes.core` (Red Hat certified) for the service account.
- Credentials: *Red Hat Ansible Automation Platform* (always) and *OpenShift API (configuration as code)* (only for the
  virtual machines inventory; rights to create a namespace, ClusterRole and bindings).
- The inventory sync's execution environment needs `kubevirt.core` (included in `ee-supported-rhel9`).

## Variables

See `defaults/main.yml`. Inputs normally supplied by the job template survey:

| Variable | Default | Notes |
|---|---|---|
| `openshift_automation_platform_virtual_machine_inventory` | `false` | `true` = create or update the inventory, source and credential |
| `openshift_automation_platform_virtual_machine_inventory_namespaces` | `[]` | List or comma-separated; empty = every namespace |
| `openshift_automation_platform_virtual_machine_inventory_verify_ssl` | `true` | Inventory sync verifies the cluster API certificate |
| `openshift_automation_platform_validate_certs` | `true` | This job's cluster API calls |

Other settings: inventory, source and credential names, organization (empty = `site_organization`), extra source
variables, execution environment, service account namespace and names.
