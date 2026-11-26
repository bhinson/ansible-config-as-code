# openshift_automation_x2ansible

Deploys [x2ansible](https://x2ansible.github.io) on OpenShift. It converts Chef, Puppet and Salt code to Ansible with a
large language model (LLM).

- **User interface:** the community x2a plug-ins for Red Hat Developer Hub (RHDH), in their own Backstage instance
  ("Conversion Hub" page and a "conversion project" software template).
- **Work:** each migration phase (init, analyze, migrate, publish) runs the `x2a-convertor` image as a Kubernetes Job in
  the same namespace. The Job clones the source repository and pushes results with the signed-in user's GitHub token.
- **Publish:** a dedicated Ansible Automation Platform (AAP) user ("Organization Project Admin" in the chosen
  organization, default `Default`) creates an AAP project for each migration.

The x2a plug-ins and the convertor are community projects, not supported by Red Hat. Collections: `redhat.openshift`,
`kubernetes.core`, `ansible.platform` (all Red Hat certified).

## What it creates

| Object | Purpose |
|---|---|
| RHDH operator (shared role `openshift_automation_developer_hub_operator`) | Installs or adopts the operator |
| Namespace, ServiceAccount `x2a-sa`, Role/RoleBinding, ClusterRole `x2a-list-pods-<namespace>` | The backend creates Jobs and temporary Secrets; the plug-in's connection test lists pods |
| AAP user `x2ansible` + role + token, Secret `<name>-platform-user` | Publishing; a token is created only when the stored one is missing or rejected |
| Secret `<name>-secrets` | GitHub OAuth app, LLM and AAP settings (environment variables) |
| ConfigMap `<name>-ca-bundle` | Cluster root CA + AAP CA, trusted by the backend and every Job |
| ConfigMaps `<name>-app-config`, `<name>-dynamic-plugins`, Backstage `<name>` | The instance (Route `backstage-<name>`) |
| Optional: VirtualMachine + Service `x2ansible-target`, Secret `x2ansible-target-ssh-key`, AAP machine credential + inventory "x2ansible - target virtual machine" | A RHEL host for running converted roles (registered with an activation key, to Satellite or Red Hat) |

## Inputs (see `defaults/main.yml`)

- LLM: `openshift_automation_x2ansible_llm_url` (OpenAI-compatible, with `/v1`), `_llm_token`, `_llm_model` (LiteLLM name,
  for example `openai/<model>`; needs tool calling).
- Sign-in: `openshift_automation_x2ansible_github_client_id` / `_github_client_secret`. Create a GitHub OAuth app with
  the x2ansible URL as homepage and `<URL>/api/auth/github/handler/frame` as callback (the job output shows both).
  Without one, `openshift_automation_x2ansible_allow_guest_sign_in: true` deploys with guest sign-in (Git steps fail).
- On reruns an empty LLM token or GitHub client secret keeps the stored one.
- `openshift_automation_x2ansible_resource_profile`: `small` lowers CPU requests for x2ansible and the Jobs.
- Images: the convertor tag is pinned (`sha-<commit>`; upstream has no version tags); plug-in tag
  `bs_<Backstage version>__<plug-in version>` must match the Backstage version of the RHDH release.

## Running a converted role

After x2ansible publishes a migration, AAP has a project for it. Create a job template with that project, the inventory
and the machine credential "x2ansible - target virtual machine", and launch it.

## Remove

Delete the namespace (Jobs, Secrets and the database go with it), the ClusterRole and ClusterRoleBinding labelled
`app.kubernetes.io/part-of=x2ansible`, the AAP user and the projects it published, the target VM's
AAP inventory and credential, and its Satellite or Red Hat registration.
