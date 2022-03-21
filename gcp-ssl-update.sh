#!/bin/bash
set -e

# Extract working archive
tar -zxf letsencrypt.tar.gz

# Extract args into named values
DOMAIN=$1
FRONT_END_NAME_IPV4=$2
FRONT_END_NAME_IPV6=$3
SERIAL=`openssl x509 -in ./live/$DOMAIN/cert.pem -serial -noout | awk -F= '{print tolower($2)}'`
NAME=`echo $DOMAIN-$SERIAL | cut -b1-62 | sed 's/\./-/g'`

# Join array by delimiter - see https://stackoverflow.com/a/17841619/2242975
function join_by { local IFS="$1"; shift; echo "$*"; }

if `gcloud compute ssl-certificates list | grep -q $SERIAL`; then
   echo 'Certificate with this serial number was already processed, skipping loadbalancer update'
else
    echo 'In else'
    echo "Domain $DOMAIN"
    echo "Front_end $FRONT_END_NAME_IPV4"
    # Create a new ssl-certificate entry
    gcloud compute ssl-certificates create $NAME --certificate=./live/$DOMAIN/fullchain.pem --private-key=./live/$DOMAIN/privkey.pem

    # Get the most recent certificate for this domain (should be the one we just created)
    NEW_CERT=`gcloud compute ssl-certificates list --filter="name~'^$DOMAIN.*'" --limit 1 --sort-by ~creationTimestamp --format="value(name)"`

    if [[ ! -z "$FRONT_END_NAME_IPV4" ]]; then
        echo 'Updating IPV4 forwarding leg'

        PROXY_IPV4=`gcloud compute forwarding-rules list --filter="name~'$FRONT_END_NAME_IPV4'" --format="value(target.scope())"`
        if [[ -z "$PROXY_IPV4" ]]; then
            echo "No forwarding-rule found, associated with front-end name $FRONT_END_NAME_IPV4, did you spell it correctly?"
            exit 1
        fi

        # Get all certificates currently on the load-balancer
        EXISTING_CERTS_IPV4=`gcloud compute target-https-proxies describe $PROXY_IPV4 --format="flattened(sslCertificates[].basename())" | awk '{print $2}'`
        # Strip any for this domain
        OTH_CERTS_IPV4=`echo $EXISTING_CERTS_IPV4 | grep -v "^$DOMAIN" || true`

        # Add the new cert plus all other domains, to make a comma-separated list of all certs to use
        ALL_CERTS_IPV4=`join_by , $NEW_CERT $OTH_CERTS_IPV4`

        # Set the certificate list on the load-balancer
        gcloud compute target-https-proxies update $PROXY_IPV4 --ssl-certificates=$ALL_CERTS_IPV4
    fi

    if [[ ! -z "$FRONT_END_NAME_IPV6" ]]; then
       echo 'Updating IPV6 forwarding leg'

        PROXY_IPV6=`gcloud compute forwarding-rules list --filter="name~'$FRONT_END_NAME_IPV6'" --format="value(target.scope())"`
        if [[ -z "$PROXY_IPV6" ]]; then
            echo "No forwarding-rule found, associated with front-end name $FRONT_END_NAME_IPV6, did you spell it correctly?"
            exit 1
        fi

        # Get all certificates currently on the load-balancer
        EXISTING_CERTS_IPV6=`gcloud compute target-https-proxies describe $PROXY_IPV6 --format="flattened(sslCertificates[].basename())" | awk '{print $2}'`
        # Strip any for this domain
        OTH_CERTS_IPV6=`echo $EXISTING_CERTS_IPV6 | grep -v "^$DOMAIN" || true`

        # Add the new cert plus all other domains, to make a comma-separated list of all certs to use
        ALL_CERTS_IPV6=`join_by , $NEW_CERT $OTH_CERTS_IPV6`

        # Set the certificate list on the load-balancer
        gcloud compute target-https-proxies update $PROXY_IPV6 --ssl-certificates=$ALL_CERTS_IPV6
    fi
fi
