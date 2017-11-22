#!/bin/bash 

bld="$(tput bold)"
rst="$(tput sgr0)"

msg() {
  case "$3" in
    red) c=1;;
    grn|green) c=10;;
    ylw|yellow) c=11;;
    blu|blue) c=12;;
    *) c=15;; 
  esac

  ctx="$1"
  txt="$2"
  col="$(tput setaf $c)"

  echo
  echo "${txt}" | awk '{print "==> '$col$ctx$rst': " $0}'
  sleep 1
}

# =========================================================================== CLEANUP

killall vault
sleep 5

rm -f client.* server.* ca-root.* ca-inter.* vault.hcl unseal.keys *.token
rm -rf vault/

# =========================================================================== START SERVER

if [ ! -f vault.crt ] || [ ! -f vault.key ]
then
  curl -sSL https://raw.githubusercontent.com/frntn/x509-san/master/gencert.sh | CRT_CN="xoqnap" CRT_SAN="DNS.1:localhost,IP.1:127.0.0.1" CRT_FILENAME="vault" bash
fi

cat <<EOF > vault.hcl
backend "file" {
  path = "vault"
}

listener "tcp" {
  address = "127.0.0.1:8200"
 
  tls_disable = 0
  tls_cert_file = "vault.crt"
  tls_key_file = "vault.key"  
}

plugin_directory = "/etc/vault/plugins"

disable_mlock = true
EOF

export VAULT_SKIP_VERIFY=true
export VAULT_ADDR="https://127.0.0.1:8200"

nohup vault server -config=vault.hcl & 
sleep 5

# =========================================================================== INIT/UNSEAL/AUTH

vault init -key-shares=1 -key-threshold=1                  \
    | tee                                                  \
    >(awk '/^Initial Root Token:/{print $4}' > root.token) \
    >(awk '/^Unseal Key/{print $4}' > unseal.keys)

vault unseal $(cat unseal.keys)

vault auth $(cat root.token)

# =========================================================================== IMPORTANT NOTE

echo "$bld
=============================================================================
IMPORTANT NOTE: 
  Vault uses mount points : kv, database, pki, aws, ...
  The 'pki' mount points has one 'root' and one 'intermediate' => pki/root/xxx and pki/intermediate/xxx
BUT
  The 'pki' mount points can have one and only one privatekey
  Therefore one mount point cannot handle both Root & Intermediate CA
  (See: https://github.com/hashicorp/vault/issues/1586#issuecomment-230300216)
SO 
  You'll need one 'pki' mount point per certificate of your certificate chain
=============================================================================
$rst
"

umask 377

# =========================================================================== ROOT

msg rootca-mount "Mount ROOT CA" red
vault mount -max-lease-ttl="87600h" -path="pki-root"  -description="Acme - ROOT CA" pki

msg rootca-urls "Configure ROOT CA distribution endpoints (CA/CRL)" red
vault write pki-root/config/urls                          \
    issuing_certificates="https://pki.acme.inc/l0/ca"     \
    crl_distribution_points="https://pki.acme.inc/l0/crl"

msg rootca-generate-crt "Generate ROOT CA (Self Signed)" red
vault write -format=json pki-root/root/generate/exported    \
    common_name="ACME Authority - L0"                       \
    alt_names="acme.inc,*.acme.inc"                         \
    key_type="ec" key_bits="256"                            \
    | tee                                                   \
    >(jq -r .data.certificate > ca-root.pem.crt)            \
    >(jq -r .data.issuing_ca  > ca-root.issuing_ca.pem.crt) \
    >(jq -r .data.private_key > ca-root.pem.key)            \
    >/dev/null

# =========================================================================== INTERMEDIATE

msg interca-mount "Mount INTERMEDIATE CA" ylw
vault mount -max-lease-ttl="8760h" -path="pki-inter" -description="Acme - INTERMEDIATE CA" pki

msg interca-urls "Configure INTERMEDIATE CA distribution endpoints (CA/CRL)" ylw
vault write pki-inter/config/urls                         \
    issuing_certificates="https://pki.acme.inc/l1/ca"     \
    crl_distribution_points="https://pki.acme.inc/l1/crl"

msg interca-generate-csr "Generate the INTERMEDIATE CA Certificate Sign Request" ylw
vault write -format=json pki-inter/intermediate/generate/exported               \
    common_name="ACME Authority - L1"             \
    alt_names="acme.inc,*.acme.inc"               \
    key_type="ec" key_bits="256"                  \
    exclude_cn_from_sans="true"                   \
    | tee                                         \
    >(jq -r .data.csr         > ca-inter.pem.csr) \
    >(jq -r .data.private_key > ca-inter.pem.key) \
    >/dev/null

msg rootca-sign-interca-csr "Retrieve the INTERMEDIATE CA Certificagte (i.e. sign the INTERMEDIATE CSR with the ROOT CA)" red
vault write -format=json pki-root/root/sign-intermediate     \
    common_name="ACME Authority - L1"                        \
    alt_names="acme.inc,*.acme.inc"                          \
    csr="@ca-inter.pem.csr"                                  \
    ttl="720h"                                               \
    | tee                                                    \
    >(jq -r .data.certificate > ca-inter.pem.crt)            \
    >(jq -r .data.issuing_ca  > ca-inter-issuing_ca.pem.crt) \
    >/dev/null

msg interca-upload-crt "Upload INTERMEDIATE CA to vault" ylw
vault write pki-inter/intermediate/set-signed \
    certificate="@ca-inter.pem.crt"

# =========================================================================== Role

msg interca-role "Create 'server' role to configure the to-be-created server certificates attributes" ylw
vault write pki-inter/roles/server \
    client_flag="false"            \
    allow_any_name="false"         \
    allowed_domains="acme.inc"     \
    allow_subdomains="true"        \
    key_type="ec" key_bits="256"   \
    max_ttl="72h"

msg interca-role "Create 'client' role to configure the to-be-created client certificates attributes" ylw
vault write pki-inter/roles/client \
    server_flag="false"            \
    enforce_hostnames="false"      \
    allow_any_name="true"          \
    key_type="ec" key_bits="256"   \
    max_ttl="72h"

# =========================================================================== Policy

msg sys-create-policy "Create 'pki-issue-server' policy allowed to issue server certificates'    $bld#ACL$rst" blu
vault policy-write pki-issue-server \
    <(echo 'path "pki-inter/issue/server" { policy = "write" }')

msg sys-create-policy "Create 'pki-issue-server' policy allowed to issue client certificates'    $bld#ACL$rst" blu
vault policy-write pki-issue-client \
    <(echo 'path "pki-inter/issue/client" { policy = "write" }')

# =========================================================================== Token

msg sys-create-token "Create 'server' token with the 'pki-issue-server' policy    $bld#SESSION$rst" blu
vault token-create -format=json -policy=pki-issue-server \
    | jq -r .auth.client_token                           \
    > server.token

msg sys-create-token "Create 'client' token with the 'pki-issue-client' policy   $bld#SESSION$rst" blu
vault token-create -format=json -policy=pki-issue-client \
    | jq -r .auth.client_token                           \
    > client.token

# =========================================================================== Auth + Generate Server Certificate

msg issue-servercrt "Authenticate to vault using the 'server' token     $bld#AUTH$rst" grn
vault auth $(cat server.token)

msg issue-servercrt "Generate a server certificate ( exec command 'ls -l server.*' to see the private key, certificate, ca chain, issuing ca )    $bld#GENERATE$rst" grn
vault write -format=json pki-inter/issue/server                 \
    common_name="admin.staging.acme.inc"                        \
    | tee                                                       \
    >(jq -r .data.certificate      > server.pem.crt)            \
    >(jq -r .data.private_key      > server.pem.key)            \
    >(jq -r .data.issuing_ca       > server.issuing_ca.pem.crt) \
    >(jq -r '.data.ca_chain | .[]' > server.ca_chain.pem.crt)   \
    >/dev/null

# =========================================================================== Auth + Generate Client Certificate

# Authentification et generation d'un certificat CLIENT
msg issue-clientcrt "Authenticate to vault using the 'client' token    $bld#AUTH$rst" grn
vault auth $(cat client.token)

msg issue-clientcrt "Generate a client certificate ( exec command 'ls -l client.*' to see the private key, certificate, ca chain, issuing ca )    $bld#GENERATE$rst" grn
vault write -format=json pki-inter/issue/client                 \
    common_name="Matthieu Fronton"                              \
    | tee                                                       \
    >(jq -r .data.certificate      > client.pem.crt)            \
    >(jq -r .data.private_key      > client.pem.key)            \
    >(jq -r .data.issuing_ca       > client.issuing_ca.pem.crt) \
    >(jq -r '.data.ca_chain | .[]' > client.ca_chain.pem.crt)   \
    >/dev/null

msg interca-issue-clientcrt "Pack client certificate & private key in one protected 'client.p12' file     $bld#PKCS12$rst" grn
< /dev/urandom tr -dc "+=\-%*\!&#':;{}()[]|^~\$_2-9T-Z" | head -c65 > client.p12.pass
openssl pkcs12 -export -out client.p12 -passout file:client.p12.pass -inkey client.pem.key -in client.pem.crt

umask 022
