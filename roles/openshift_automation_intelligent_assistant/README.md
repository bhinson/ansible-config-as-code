# openshift_automation_intelligent_assistant

Enables the automation intelligent assistant (the Ansible Lightspeed chat in the Ansible Automation Platform (AAP) UI)
on an operator-based AAP installation on OpenShift and connects it to a large language model (LLM) provider.
Follows the AAP 2.7 extend guide, "Deploy the automation intelligent assistant on OpenShift Container Platform".

Job template: "Intelligent assistant | Enable on OpenShift" (area `automation_intelligent_assistant`); the survey takes
the LLM provider type, base URL, model and API token, like the Automation Orchestrator LLM integration.

## What it does
1. Finds the AnsibleAutomationPlatform custom resource (CR): the named one, else the one whose status URL is
   `aap_hostname`, else the only one.
2. Writes the chatbot configuration Secret (`chatbot_llm_provider_type`, `chatbot_url`, `chatbot_model`,
   `chatbot_token`, optional `chatbot_model_config_extras` / `chatbot_agent_config_extras`, and `aap_gateway_url` /
   `aap_controller_url` for the built-in Model Context Protocol (MCP) servers). The name is
   `<prefix>-<hash of the content>`: the Lightspeed operator doesn't notice edits to a Secret it already uses (the docs
   say to use a new Secret for a new model), so every change becomes a new Secret. Superseded Secrets made by the role
   (label `app.kubernetes.io/component=intelligent-assistant-chatbot-configuration`) are deleted afterwards.
3. Sets `spec.lightspeed: {disabled: false, chatbot_config_secret_name: <Secret>}` (plus
   `openshift_automation_intelligent_assistant_spec_overrides`) on the AAP CR.
4. **AAP operator quirk:** it creates the AnsibleLightspeed CR `<AAP CR name>-lightspeed` from `spec.lightspeed` only
   when that CR doesn't exist yet, and never passes later changes on (checked in the operator's
   `common/tasks/check_existing_components.yml`). So when the AnsibleLightspeed CR exists, the role also merges the new
   Secret name (and overrides) into it; the Lightspeed operator then redeploys the chatbot.
5. Waits until the AnsibleLightspeed status reports the new Secret (`status.chatbotConfigurationSecret`) and the
   deployments `<name>-api` and `<name>-chatbot-api` are rolled out.

`state: absent` sets `spec.lightspeed.disabled: true`, deletes the AnsibleLightspeed CR, waits for its pods to go and
deletes the role's Secrets (the docs' "Disable the automation intelligent assistant on an operator-based deployment").

Rerun without the token: an empty token keeps the token of the Secret in use, so only changed settings need input.

## Requirements
- AAP 2.6 or later on OpenShift (operator-based); the AAP operator bundle includes the Lightspeed operator.
- An LLM with tool calling. The Lightspeed operator accepts the provider types `rhoai_vllm` (Red Hat OpenShift AI, Red Hat
  Enterprise Linux AI or Red Hat AI Inference Server with vLLM; the default when unset), `openai` and `azure_openai`.
  The docs also list `rhelai_vllm`, which the operator rejects.
- Collections: `redhat.openshift`, `kubernetes.core`. Credentials: OpenShift API (configuration as code); the Red Hat
  Ansible Automation Platform credential is optional (only `aap_hostname` is used, to pick the CR).

## Variables
| Variable | Default | Notes |
|---|---|---|
| `openshift_automation_intelligent_assistant_state` | `present` | `absent` disables and removes the assistant |
| `openshift_automation_intelligent_assistant_platform_namespace` / `_platform_name` | `""` | Empty = discover the AAP CR |
| `openshift_automation_intelligent_assistant_llm_provider_type` | `rhoai_vllm` | `rhoai_vllm`, `openai` or `azure_openai` |
| `openshift_automation_intelligent_assistant_llm_url` | `""` | Inference API base URL (required) |
| `openshift_automation_intelligent_assistant_llm_model` | `""` | Model name (required) |
| `openshift_automation_intelligent_assistant_llm_token` | `""` | API token; empty = keep the current Secret's token |
| `openshift_automation_intelligent_assistant_llm_model_config_extras` | `""` | JSON object (or dict), for example Azure `api_version` |
| `openshift_automation_intelligent_assistant_llm_agent_config_extras` | `""` | JSON object (or dict), for example `chatbot_temperature_override` |
| `openshift_automation_intelligent_assistant_mcp_servers` | `gateway_and_controller` | `gateway`, `none` |
| `openshift_automation_intelligent_assistant_mcp_gateway_url` / `_mcp_controller_url` | `""` | Empty = `http://<AAP CR name>` / `http://<AAP CR name>-controller-service` |
| `openshift_automation_intelligent_assistant_secret_prefix` | `""` | Empty = `<AAP CR name>-intelligent-assistant` |
| `openshift_automation_intelligent_assistant_spec_overrides` | `{}` | Merged over `spec.lightspeed` (for example `chatbot_extra_settings` for bring your own knowledge) |
| `openshift_automation_intelligent_assistant_validate_certs` | `true` | This job verifies the cluster API certificate |
| `openshift_automation_intelligent_assistant_wait_retries` / `_wait_delay` | `180` / `10` | |

## Troubleshooting
- Chatbot pods fail TLS after an OpenShift service CA rotation: restart `<name>-api` and `<name>-chatbot-api` (docs).
- MCP containers: the `<name>-chatbot-api` pod has `ansible-mcp-lightspeed` (gateway URL set) and
  `ansible-mcp-controller` (controller URL set).
