#!/bin/bash

set -e
set -x

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

# Get 2 most recent certificates for this domain
CUR_CERTS=`gcloud compute ssl-certificates list --filter="name~'^$DOMAIN.*'" --limit 2 --sort-by ~creationTimestamp --format="value(name)"`

# Get all certificates currently on the load-balancer, except for this domain
# TODO: Setting an empty value causes set -e to mark this as an error
OTH_CERTS=`gcloud compute target-https-proxies describe $PROXY_NAME --format="flattened(sslCertificates[].basename())" | awk '{print $2}' | grep -v "^$DOMAIN"`

# Add the 2 newest certs plus all other domains, to make a comma-separated list of all certs to use
ALL_CERTS=`join_by , $CUR_CERTS $OTH_CERTS`

# Set the certificate list on the load-balancer
gcloud compute target-https-proxies update $PROXY_NAME --ssl-certificates=$ALL_CERTS
