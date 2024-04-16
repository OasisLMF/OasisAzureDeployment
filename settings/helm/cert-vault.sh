#!/bin/bash

wget https://dl.cacerts.digicert.com/DigiCertGlobalRootCA.crt.pem -O keycloak-cert.pem
# Variables
KEY_VAULT_NAME="oasis-f54epckzwcpb4"
CERT_NAME="keycloak-cert"
CERT_FILE="keycloak-cert.pem"
#CONFIGMAP_NAME="keycloak-cert-configmap"
#SECRET_NAME="keycloak-cert-secret"


#CERT_DATA=$(kubectl get configmap $CONFIGMAP_NAME -o jsonpath='{.data.tls\.crt}')

# Check if the certificate file exists
if [ ! -f "$CERT_FILE" ]; then
    echo "Error: CErtificate file $CERT_FILE does not exist."
    exit 1
fi


#echo "$CERT_DATA" > $CERT_FILE

az keyvault certificate import \
  --vault-name $KEY_VAULT_NAME \
  --file $CERT_FILE \
  --name $CERT_NAME \
  #--enbled true

#rm $CERT_FILE