---
name: automation-orchestrator-llm-integration
description: >-
  Connect Red Hat Automation Orchestrator (AO) to an OpenAI API-compatible
  large language model (LLM) provider with the
  automation_orchestrator_llm_integration role - LLM Provider credential,
  connection test and model discovery, enabled/default models, provider TLS
  settings. Use when editing that role or debugging LLM integration failures.
---

# Connect Automation Orchestrator to an LLM provider

Role: `roles/automation_orchestrator_llm_integration` (playbook `playbooks/automation_orchestrator_llm_integration.yml`,
job template "Automation Orchestrator | Configure LLM provider integration"). Docs: AO 2026.8 configure guide,
"Configure an LLM provider integration" and "Integration configuration field reference".

## Rules
- **Use the documented API.** AO serves its OpenAPI 3.1 specification at `https://<AO host>/api_docs/v1/openapi.json`
  (Swagger UI at `/api_docs/v1/docs`, no authentication needed; develop guide, "Access and use the OpenAPI
  specification"). Read request and response schemas there instead of guessing; the configure guide only shows the UI.
- The endpoint must implement the **OpenAI v1 API**. Provider hints: `red_hat_ai`, `openai`, `anthropic`, `gemini`,
  `custom`; `base_url` is required for `red_hat_ai` and `custom`.
- The integration credential is only for health checks and discovery. Workflows set runtime credentials in the
  workflow builder.
- Never log the API key (`no_log: true` on every task that carries it).

## API flow (schemas from the OpenAPI specification)
1. Credential: `POST /api/v1/credentials` with the built-in credential type **LLM Provider** (single secret input
   `api_key`), a `project_id` (the default project) and `inputs: {api_key}`.
2. Test and discover: `POST /api/v1/integrations/discover` with `{integration_type: llm_provider, configuration,
   credential_id}`. The response (`DiscoverResult`) has `success`, `error`, and `discovered_models` (`id` = provider
   model ID, `name`, `description`).
3. Create: `POST /api/v1/integrations` (`IntegrationCreate`) with `configuration` = `LLMProviderConfiguration`
   `{integration_type: llm_provider, provider_hint, base_url, allow_http, insecure_skip_tls_verify, ca_certificate}`,
   `management_credential_id`, `scope`, and `discovered_models` as `InitialModelSelection` items
   `{model_id, name, description, enabled, is_default}`.
4. Update: `PATCH /api/v1/integrations/{id}` (`IntegrationUpdate`), then `POST /api/v1/integrations/{id}/validate`.
5. Models: `GET /api/v1/integrations/{id}/models` returns `LLMModelRead` items where **`id` is AO's UUID** and
   `model_id` is the provider's ID. `PATCH .../models/bulk_update` (`{model_ids: [UUIDs], enabled}`) and
   `PATCH .../models/{UUID}` (`{is_default: true}`) take the UUIDs.

## TLS
- Job to AO: `automation_orchestrator_llm_integration_validate_certs` (the AO route is verified with the OpenShift
  ingress certificate authority (CA) unless you pass a bundle).
- AO to provider: prefer `..._provider_ca_certificate` (PEM) for internally signed certificates;
  `..._provider_validate_certs: false` sets `insecure_skip_tls_verify` and should be a last resort.
- A provider on a private IP address must also be in `APP_INTEGRATION_URL_ALLOWED_HOSTS`, which the
  `automation_orchestrator_configuration` role owns (its extra allowed hosts), or AO rejects the base URL.

## Troubleshooting
- Discovery fails with an authentication error: the API key is wrong or revoked at the provider.
- Discovery times out: check that the AO pods can reach the endpoint (DNS, proxy, egress rules). The connection test
  timeout is 10 seconds by default (AO **Settings > Integrations**).
- Integration shows Available but agent steps fail: transient provider issues; see the configure guide entry
  "LLM provider unreachable during execution".
