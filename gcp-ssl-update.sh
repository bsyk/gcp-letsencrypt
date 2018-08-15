#!/bin/bash
set -e

# Extract working archive
tar -zxf letsencrypt.tar.gz

# Extract args into named values
DOMAIN=$1
PROXY_NAME=$2
SERIAL=`openssl x509 -in ./live/$DOMAIN/cert.pem -serial -noout | awk -F= '{print tolower($2)}'`
NAME=`echo $DOMAIN-$SERIAL | sed 's/\./-/g'`

# Join array by delimiter - see https://stackoverflow.com/a/17841619/2242975
function join_by { local IFS="$1"; shift; echo "$*"; }

# Create a new ssl-certificate entry
gcloud compute ssl-certificates create $NAME --certificate=./live/$DOMAIN/fullchain.pem --private-key=./live/$DOMAIN/privkey.pem

# Get the most recent certificate for this domain (should be the one we just created)
NEW_CERT=`gcloud compute ssl-certificates list --filter="name~'^$DOMAIN.*'" --limit 1 --sort-by ~creationTimestamp --format="value(name)"`

# Get all certificates currently on the load-balancer
EXISTING_CERTS=`gcloud compute target-https-proxies describe $PROXY_NAME --format="flattened(sslCertificates[].basename())" | awk '{print $2}'`
# Strip any for this domain
OTH_CERTS=`echo $EXISTING_CERTS | grep -v "^$DOMAIN" || true`

# Add the new cert plus all other domains, to make a comma-separated list of all certs to use
ALL_CERTS=`join_by , $NEW_CERT $OTH_CERTS`

# Set the certificate list on the load-balancer
gcloud compute target-https-proxies update $PROXY_NAME --ssl-certificates=$ALL_CERTS
