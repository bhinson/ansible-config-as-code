---
name: automation-orchestrator-install-openshift
description: >-
  Install, size, or troubleshoot Red Hat Automation Orchestrator (AO) on
  OpenShift with the openshift_automation_orchestrator role - operator, bring-your-own
  PostgreSQL, AutomationOrchestrator custom resource (CR), Temporal migration failures, database
  connection sizing. Use when editing that role or debugging an AO install.
---

# Install Automation Orchestrator on OpenShift

Role: `roles/openshift_automation_orchestrator` (playbook `playbooks/openshift_automation_orchestrator.yml`). It only installs AO;
connecting Ansible Automation Platform (AAP) is a separate step (skill `automation-orchestrator-platform-integration`, role `automation_orchestrator_configuration`). Facts below were checked
against AO 2026.8 and its official docs (plan, install, configure guides).

## Rules
- **PostgreSQL 15** is the supported/tested version. Don't move to 16 without Red Hat support for it.
- Three databases: `orchestrator` (backend), `temporal`, `temporal_visibility`. The temporal user needs `CREATEDB`
  and owns both temporal databases.
- Secrets (`ao-backend-db`, `ao-temporal-db` with keys `database`/`username`/`password`, and `ao-admin-password`)
  are created **once** and never rotated by re-runs. Never print their values.
- **Back up the AO database separately**: the AAP backup CR does not cover it.
- The CR has **no AAP connection field**. AAP is connected inside the application after install.

## Custom resource facts
- Required: `spec.postgres.host`, `spec.postgres.backendDatabase.secretRef`, `spec.postgres.temporalDatabase.secretRef`.
- `workflowHttpRequestAllowedHosts`: internal hosts that workflow HTTP-request nodes may call. Private IPs are blocked
  by default (server-side request forgery protection), so add the AAP gateway host if it resolves to a private address
  (`openshift_automation_orchestrator_allowed_hosts`).
- `fileStorage` (S3) is optional. Without it, file uploads return 503.
- Internal mTLS uses operator-generated self-signed certs that are not auto-rotated; use `spec.tls` for your own.
- Read the schema from the installed custom resource definition (CRD) rather than guessing:
  `oc get crd automationorchestrators.aap.ansible.com -o jsonpath='{.spec.versions[0].schema.openAPIV3Schema.properties.spec}'`.
  The file-based catalog only carries metadata; the full CRD is in the bundle image.

## Sizing database connections
- Each backend/worker/background-worker replica opens up to poolSize + maxOverflow = 20 + 10 = **30** connections.
- Docs: 230 for 2 backend + 2 worker + 1 background worker, **+30 per extra background worker**. The operator's default
  horizontal pod autoscaler max is 5 (about 350 at peak), so the role caps it (`openshift_automation_orchestrator_background_worker_max: 2`) and uses 300.
- The role asserts `(2 + 2 + background_worker_max) x 30 + 20 <= max_connections` before deploying. Raise
  `..._postgres_memory_limit` with `max_connections` (about 5-10 MB per slot).
- Default requests: backend/worker/background-worker 250m/256Mi, temporal 500m/512Mi (limit 4Gi), UI 20m/64Mi, Redis 10m/32Mi.

## Troubleshooting
- **Temporal migration fails** with `pq: database "temporal_visibility" does not exist` (job BackoffLimitExceeded, CR
  `Degraded=True` reason `MigrationFailed`). The docs say the operator creates this database, but AO 2026.8 does not. The role
  creates it (init script on fresh installs, `k8s_exec` on existing databases). Once it exists the operator retries on its own
  and the CR goes Ready in about 5 minutes.
- Failed migration pods linger after recovery:
  `oc delete pod -n <namespace> --field-selector=status.phase=Failed`.
- **Changing the PostgreSQL major version** needs a fresh data directory: delete the CR, the StatefulSet and persistent volume claim
  `data-ao-postgres-0`, then re-run. Only safe while AO holds no data; otherwise dump/restore all three databases.
- Wait for readiness with `oc wait automationorchestrator/<name> -n <namespace> --for=condition=Ready --timeout=20m`.

## Admin access
- UI admin username is **`admin`**; the password is in Secret `ao-admin-password` (or the vaulted value you passed).
- Reset (configure guide): `oc exec -it -n <namespace> deploy/<cr-name>-backend -- ao-admin reset-password --username admin`
  (prompts for the password; revokes all sessions). Local passwords need 14+ characters and 3 of 4 character classes.
- A valid **AAP subscription** covers AO; there is no separate subscription.
