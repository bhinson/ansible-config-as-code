# openshift_automation_orchestrator

Installs Red Hat Automation Orchestrator (AO) on OpenShift:

1. Operator `automation-orchestrator-operator` (AllNamespaces OperatorGroup, Subscription, waits for the ClusterServiceVersion).
2. Instance namespace and Secrets (`ao-backend-db`, `ao-temporal-db`, `ao-admin-password`), generated once and never
   rotated by re-runs.
3. Bring-your-own **PostgreSQL 15** (`registry.redhat.io/rhel9/postgresql-15`, the version AO 2026.8 supports) with TLS
   from the OpenShift service CA, databases `orchestrator`, `temporal`, `temporal_visibility`, and `max_connections` sized
   for the replica count.
4. `AutomationOrchestrator` custom resource (CR), with the background-worker horizontal pod autoscaler capped; then waits for `Ready=True` and reports the route.

A pre-flight assert fails the run if `(2 backend + 2 worker + background_worker_max) x 30 + 20 > max_connections`.

Uses `redhat.openshift` (Red Hat certified; applies objects) and `kubernetes.core` (Red Hat certified; lookups). Authentication comes from `K8S_AUTH_HOST`, `K8S_AUTH_API_KEY`, `K8S_AUTH_SSL_CA_CERT`.

## Connecting Ansible Automation Platform

This role only installs AO. Run the `automation_orchestrator_configuration` role afterwards to set the integration allowlists, create the
Ansible Automation Platform (AAP) integration and set up AAP single sign-on.

## Variables

See `defaults/main.yml`. Common overrides:

| Variable | Default | Notes |
|---|---|---|
| `openshift_automation_orchestrator_operator_channel` | `stable` | |
| `openshift_automation_orchestrator_operator_approval` | `Automatic` | Same as the other operators on the cluster |
| `openshift_automation_orchestrator_namespace` | `automation-orchestrator` | |
| `openshift_automation_orchestrator_allowed_hosts` | `[]` | Internal hostnames workflow HTTP nodes may call (e.g. the AAP gateway) |
| `openshift_automation_orchestrator_ingress_host` | `""` | Route host; empty = OpenShift-generated |
| `openshift_automation_orchestrator_admin_password` | generated | Set from Ansible Vault to choose it |
| `openshift_automation_orchestrator_postgres_deploy` | `true` | `false` to point at an existing PostgreSQL |
| `openshift_automation_orchestrator_postgres_storage_class` / `_size` | `""` (cluster default) / `10Gi` | |
| `openshift_automation_orchestrator_postgres_image` | `rhel9/postgresql-15` | Supported version; 16 is untested by Red Hat |
| `openshift_automation_orchestrator_postgres_max_connections` | `300` | Docs: 230 for 2/2/1, +30 per extra background worker |
| `openshift_automation_orchestrator_postgres_memory_limit` | `3Gi` | About 5-10 MB per connection slot |
| `openshift_automation_orchestrator_validate_certs` | `true` | Verify the cluster API certificate on Kubernetes calls |
| `openshift_automation_orchestrator_background_worker_min` / `_max` | `1` / `2` | Operator default max is 5 (would need about 350 connections) |

## Known issues handled

- Changing the PostgreSQL major version needs a fresh data directory: delete the CR, the StatefulSet and persistent volume claim
  `data-ao-postgres-0`, then re-run (only safe while AO holds no data; otherwise dump/restore all three databases).
- The operator's Temporal migration job needs a `temporal_visibility` database and does not create it
  (`pq: database "temporal_visibility" does not exist`, job BackoffLimitExceeded). The init script creates it on fresh
  installs and a `k8s_exec` task creates it on existing databases.
- The CR has no AAP connection field; connect to AAP inside the application after install.
