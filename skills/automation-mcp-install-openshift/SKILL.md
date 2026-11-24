---
name: automation-mcp-install-openshift
description: >-
  Deploy, configure or troubleshoot the Model Context Protocol (MCP) server for Ansible Automation Platform (AAP) on
  an operator-based AAP on OpenShift with the openshift_automation_mcp role - spec.mcp on the AnsibleAutomationPlatform
  custom resource (CR), AnsibleMCPServer, read-only versus read-write, extra settings, OAuth 2.1 and the AAP OAuth
  application, certificate errors. Use when editing that role or debugging an MCP server deployment.
---

# MCP server for AAP on OpenShift

Role: `roles/openshift_automation_mcp` (playbook `playbooks/openshift_automation_mcp.yml`, area
`configs/automation_mcp`, job template "MCP server | Install on OpenShift"). Source of truth: AAP 2.7 extend guide,
chapter "Deploy the MCP server on Ansible Automation Platform" (operator-based installation, OAuth 2.1, troubleshooting).

## How it fits together
- No separate operator install: `spec.mcp` (`disabled: false`) on the **AnsibleAutomationPlatform** CR makes the AAP
  (gateway) operator create an **AnsibleMCPServer** (`mcpserver.ansible.com/v1alpha1`) named `<AAP CR name>-mcp`
  (`spec.mcp.name` overrides). The **Ansible Lightspeed operator** (same AAP CSV) reconciles it into a Deployment,
  Service, Route and the ConfigMap `<name>-ansible-mcp-server-env-properties`.
- The AAP operator fills `public_base_url` (gateway URL) and passes the AAP CR's `bundle_cacert_secret` on to the MCP
  server; `spec.mcp` keys are merged over that and copied verbatim into the AnsibleMCPServer spec (see
  `oc explain ansiblemcpserver.spec` for the fields: `allow_write_operations`, `extra_settings`, `route_host`, `api`...).
- `status.URL` of the AnsibleMCPServer is the client URL; endpoints `/mcp`, `/mcp/discover`, `/mcp/<toolset>`; health
  at `/api/v1/health` (`{"status":"ok"}`).

## Gotchas
- **Changes are not passed on**: the AAP operator only creates the AnsibleMCPServer when it is missing
  (`check_existing_components.yml` sets `_deploy_mcp: false` once it exists). Any `spec.mcp` change therefore needs the
  AnsibleMCPServer deleted (the guide documents this for permission changes); the role does it when the running spec
  differs. The AnsibleMCPServer keeps its owner reference, so the deletion triggers an AAP reconcile that recreates it.
- **`spec.mcp.disabled: true` doesn't delete** an existing AnsibleMCPServer; delete it as well.
- **Extra setting values**: the MCP operator renders `"{{ item.value }}"`, so YAML `true` becomes `"True"`. Write strings.
- **Certificate errors** (`SELF_SIGNED_CERT_IN_CHAIN`, 400s): give the AAP CR a `bundle_cacert_secret` (key
  `bundle-ca.crt`); the init container logs "Added customer CA bundle". `IGNORE_CERTIFICATE_ERRORS=true` is development only.
- 406 from AAP on job output: ask the AI agent for JSON output (documented limitation).
- OAuth 2.1 needs an AAP OAuth application (authorization code, PKCE required, field `pkce_required`) and
  `OAUTH2_ENABLED=true`; applications created before AAP 2.7 have PKCE off.

## Debug
```bash
oc get ansiblemcpserver -n <aap namespace> -o yaml          # spec copied from spec.mcp, status.URL, conditions
oc get cm -n <aap namespace> <name>-ansible-mcp-server-env-properties -o yaml   # effective settings
oc logs -n <aap namespace> deploy/<name>
oc logs -n <aap namespace> deploy/ansible-lightspeed-operator-controller-manager | grep -i mcp
```
