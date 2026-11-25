# openshift_ansible_platform_operator

Installs or adopts the **Ansible Automation Platform (AAP) operator** on OpenShift. `openshift_automation_platform`
includes it at the start of every configuration run (`openshift_automation_platform_operator`, default `true`), so it has
no job template of its own. It doesn't create the AnsibleAutomationPlatform custom resource.

Source: AAP 2.7 install guide, "Install the Ansible Automation Platform Operator from the CLI".

- **Adopt**: if a Subscription for `ansible-automation-platform-operator` exists in any namespace, no second one is
  created. Only its channel is managed. A different channel means an AAP upgrade, so the run fails unless
  `openshift_ansible_platform_operator_allow_channel_change` is `true` (take an AAP backup first). Namespace,
  OperatorGroup, approval and source stay as they are.
- **Install**: namespace `ansible-automation-platform` (it should run only AAP), an OperatorGroup that targets it (an
  existing OperatorGroup is kept), and the Subscription (channel `stable-2.7`, automatic approval, `redhat-operators`).
- Then it waits for the Subscription's installed ClusterServiceVersion (CSV) to reach `Succeeded`. On reruns that takes
  a few API reads (seconds).

Output fact: `openshift_ansible_platform_operator_result` (`namespace`, `subscription`, `channel`,
`cluster_service_version`, `adopted`).

## Requirements

- Collections: `redhat.openshift` and `kubernetes.core` (Red Hat certified).
- Credential: *OpenShift API (configuration as code)* with rights to read Subscriptions cluster-wide and, for a fresh
  install, to create namespaces, OperatorGroups and Subscriptions.

## Variables

See `defaults/main.yml`: namespace, OperatorGroup and Subscription names, package, `channel` (survey of the configure
job template, default from `site_automation_platform_operator_channel`), approval, source, `allow_channel_change`,
`validate_certs` and waits.
