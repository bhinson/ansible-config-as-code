# Source this file (don't execute it):   source scripts/env.sh
# For LOCAL runs only (testing, --check). The normal runtime is Ansible Automation Platform, which supplies credentials itself.
# Exports connection settings for ansible-playbook from a local secrets file kept OUTSIDE this repo.
# Never prints secret values; only reports which variables were set.
#
# Inputs (environment variables, set before sourcing):
#   CONFIGURATION_AS_CODE_SECRETS_FILE     secrets file (default: ~/.config/ansible-config-as-code/secrets.yml), mode 600,
#                                          two-level YAML:
#                                            aap:
#                                              server: https://aap.example.com     # platform gateway URL
#                                              token: "<OAuth2 token>"
#                                            openshift:
#                                              server: https://api.cluster.example.com:6443
#                                              token: "<service account token>"
#   CONFIGURATION_AS_CODE_API_CA_FILE      optional PEM certificate authority (CA) bundle for the cluster API
#   CONFIGURATION_AS_CODE_INGRESS_CA_FILE  optional PEM CA bundle for the cluster's *.apps routes (AAP, AO)

_configuration_as_code_repo="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")/.." && pwd)"
CONFIGURATION_AS_CODE_SECRETS_FILE="${CONFIGURATION_AS_CODE_SECRETS_FILE:-$HOME/.config/ansible-config-as-code/secrets.yml}"

# Read <section>.<key> from a two-level YAML file (same rules as the workspace's scripts/secret.sh).
_configuration_as_code_secret() {
  awk -v sec="$1:" -v k="$2:" '
    /^[^ #]/ { s=$1 }
    s==sec && $1==k {
      sub(/^[^:]*:[ ]*/,"")
      if (substr($0,1,1)=="\"") { sub(/^"/,""); sub(/".*$/,"") } else { sub(/[ #].*$/,"") }
      print; exit
    }' "$CONFIGURATION_AS_CODE_SECRETS_FILE"
}

_configuration_as_code_export() {  # _configuration_as_code_export <ENV_NAME> <section> <key>
  _v="$(_configuration_as_code_secret "$2" "$3")"
  if [ -n "$_v" ]; then export "$1=$_v"; echo "  set   $1"; else echo "  EMPTY $1 ($2.$3 not set in secrets file)"; fi
  unset _v
}

if [ ! -r "$CONFIGURATION_AS_CODE_SECRETS_FILE" ]; then
  echo "secrets file not readable: $CONFIGURATION_AS_CODE_SECRETS_FILE" >&2
else
  echo "Loading configuration as code environment from $CONFIGURATION_AS_CODE_SECRETS_FILE"
  _configuration_as_code_export AAP_HOSTNAME aap server
  _configuration_as_code_export AAP_TOKEN aap token
  _configuration_as_code_export K8S_AUTH_HOST openshift server
  _configuration_as_code_export K8S_AUTH_API_KEY openshift token
  if [ -n "${CONFIGURATION_AS_CODE_API_CA_FILE:-}" ] && [ -r "$CONFIGURATION_AS_CODE_API_CA_FILE" ]; then
    export K8S_AUTH_SSL_CA_CERT="$CONFIGURATION_AS_CODE_API_CA_FILE"; echo "  set   K8S_AUTH_SSL_CA_CERT"
  fi

  # Combined CA bundle: public roots + the optional cluster API and *.apps CAs.
  mkdir -p "$_configuration_as_code_repo/.ansible"
  _bundle="$_configuration_as_code_repo/.ansible/ca-bundle.pem"
  _pub=""
  for _f in /etc/ssl/cert.pem /etc/pki/tls/certs/ca-bundle.crt /etc/ssl/certs/ca-certificates.crt; do
    [ -r "$_f" ] && { _pub="$_f"; break; }
  done
  # awk 1 ends every file with a newline, so a CA file without one can't merge two certificates
  awk 1 $_pub ${CONFIGURATION_AS_CODE_API_CA_FILE:+"$CONFIGURATION_AS_CODE_API_CA_FILE"} \
    ${CONFIGURATION_AS_CODE_INGRESS_CA_FILE:+"$CONFIGURATION_AS_CODE_INGRESS_CA_FILE"} > "$_bundle" 2>/dev/null
  export SSL_CERT_FILE="$_bundle" REQUESTS_CA_BUNDLE="$_bundle"
  echo "  set   SSL_CERT_FILE / REQUESTS_CA_BUNDLE (public roots + cluster CAs)"
  unset _bundle _pub _f
fi
unset -f _configuration_as_code_secret _configuration_as_code_export
unset _configuration_as_code_repo
