# automation_orchestrator_llm_integration

Connects a running Red Hat Automation Orchestrator (AO) to a large language model (LLM) provider that implements the
OpenAI v1 API (Red Hat AI, OpenAI, Anthropic, Gemini, or any compatible endpoint), so workflow agent nodes can use it.
Run it after `openshift_automation_orchestrator`. Generic: the AO URL, admin password and the certificate authority (CA)
for the AO route are discovered from the cluster when left empty.

Follows the AO 2026.8 configure guide, "Configure an LLM provider integration" (the UI wizard: details, health check
credential, model enablement). Request shapes come from the OpenAPI specification that AO serves at
`/api_docs/v1/openapi.json` (develop guide, "Access and use the OpenAPI specification").

What it does:

1. **Credential**: an AO credential of type *LLM Provider* (`api_key`), used for health checks and model discovery.
   Workflows set their own runtime credentials in the workflow builder.
2. **Connection test and discovery**: `POST /api/v1/integrations/discover`. The run fails if the test fails or if a
   requested model isn't offered.
3. **Integration**: created with the initial model selection, or updated when the provider, base URL, TLS settings,
   credential, scope or description drift. Then `POST /api/v1/integrations/{id}/validate`.
4. **Models**: enables the requested models (all discovered models when none are listed), disables the rest, and sets
   the default model. Users give provider model IDs; the role maps them to AO model IDs.

## Requirements

- Collections: `redhat.openshift` (Red Hat certified; applies objects) and `kubernetes.core` (Red Hat certified; lookups). AO REST calls use `ansible.builtin.uri` (there's no certified
  AO collection).
- Credential (in Ansible Automation Platform (AAP), attach to the job template): cluster access through the custom type
  *OpenShift API (configuration as code)* (`K8S_AUTH_HOST` / `K8S_AUTH_API_KEY` / `K8S_AUTH_SSL_CA_CERT`).
- The provider must be reachable from the AO pods. If its host resolves to a private IP address, AO rejects it unless it
  is in AO's integration allowlist: add the host to the `automation_orchestrator_configuration` role's extra allowed hosts
  (that role owns the setting).

## Variables

See `defaults/main.yml`. Inputs normally supplied by the AAP job template survey:

| Variable | Default | Notes |
|---|---|---|
| `automation_orchestrator_llm_integration_name` | `LLM provider` | Integration name in AO |
| `automation_orchestrator_llm_integration_provider` | `custom` | `red_hat_ai`, `openai`, `anthropic`, `gemini` or `custom` |
| `automation_orchestrator_llm_integration_base_url` | `""` | Required for `red_hat_ai` and `custom`, e.g. `https://llm.example.com/v1` |
| `automation_orchestrator_llm_integration_api_key` | `""` | Required; survey password field |
| `automation_orchestrator_llm_integration_enabled_models` | `[]` | List or comma-separated provider model IDs; empty = all |
| `automation_orchestrator_llm_integration_default_model` | `""` | Provider model ID; empty = leave as is |
| `automation_orchestrator_llm_integration_scope` | `global` | `global` or `project` |
| `automation_orchestrator_llm_integration_provider_validate_certs` | `true` | AO verifies the provider certificate; `false` sets `insecure_skip_tls_verify` |
| `automation_orchestrator_llm_integration_provider_ca_certificate` | `""` | PEM CA bundle AO trusts for the provider (internally signed certificates) |
| `automation_orchestrator_llm_integration_allow_http` | `false` | Permit `http://` base URLs |
| `automation_orchestrator_llm_integration_validate_certs` | `true` | This job verifies the cluster API and AO certificates |

Survey answers are strings, so `"true"`/`"false"` and comma-separated lists work.

## Verify

In AO, **Configuration > Integrations** should show the integration as Available with the expected number of enabled
models. Workflow designers can then pick it in agent nodes (global scope, or project scope for their project).
