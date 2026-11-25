# openshift_automation_developer_hub_operator

Installs, or adopts, the Red Hat Developer Hub (RHDH) operator. Shared by the roles that run on RHDH:
`openshift_automation_developer_hub` (Developer Hub with the Ansible plug-ins) and `openshift_automation_portal`
(Ansible automation portal). Both include it before creating their instances, so the operator is managed in one place.

RHDH 1.10 docs, "Install the Red Hat Developer Hub Operator": channel `fast` (every update) or `fast-<version>`
(z-stream only), **All namespaces** install mode only, recommended namespace `rhdh-operator`.

1. Looks for a Subscription to the `rhdh` package in **any** namespace. If one exists (installed in the console, or by
   the automation portal operator, which uses `openshift-operators`), it is **adopted**: channel, approval and source are
   set from this role's variables, and no second Subscription is created (two would conflict).
2. Otherwise creates the namespace, an OperatorGroup with an empty spec (All namespaces) unless the namespace already
   has one, and the Subscription.
3. Waits for the ClusterServiceVersion to succeed and for the `backstages.rhdh.redhat.com` CRD.

Sets `openshift_automation_developer_hub_operator_result` (`namespace`, `subscription`, `cluster_service_version`, `adopted`).

Uses `redhat.openshift` (applies objects) and `kubernetes.core` (lookups), both Red Hat certified. Authentication:
`K8S_AUTH_HOST`, `K8S_AUTH_API_KEY`, `K8S_AUTH_SSL_CA_CERT`; needs cluster-admin (OLM objects).

## Variables

| Variable | Default | Notes |
|---|---|---|
| `openshift_automation_developer_hub_operator_namespace` | `rhdh-operator` | Only used for a new install |
| `openshift_automation_developer_hub_operator_subscription_name` | `rhdh` | Only used for a new install |
| `openshift_automation_developer_hub_operator_channel` | `fast` | `fast-1.10` keeps the 1.10 z-stream |
| `openshift_automation_developer_hub_operator_approval` | `Automatic` | `Manual` holds updates for approval |
| `openshift_automation_developer_hub_operator_source` | `redhat-operators` | |
| `openshift_automation_developer_hub_operator_validate_certs` | `true` | Verify the cluster API certificate |

Removing the operator is not automated; the automation portal upgrade guide notes that its RHDH Subscription stays
behind (`oc delete subscription rhdh -n <namespace>`, then the ClusterServiceVersion).
