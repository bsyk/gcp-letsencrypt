# gcp-letsencrypt
Cloudbuild script to obtain and renew certificates and attach to a load-balancer in Google Cloud Platform.
This can be run in [Google Cloud Build](https://cloud.google.com/cloud-build/).

This is intended to be used to renew [letsencrypt](https://letsencrypt.org) certificates (or get certificates for a new domain) and set them to be used on an *existing* [https load-balancer](https://cloud.google.com/load-balancing/docs/https/).  
Without edits, this will try to obtain a wildcard certificate for the whole domain, including the domain apex.

> Note: This script stores the generated certificates in Google Cloud Storage between runs to avoid renewing certificates too frequently.  This may pose a security risk.

## Getting Started
There are a few steps to using this script.

1. Create an HTTPS Load-balancer  
You'll need a certificate pair in order to create the load-balancer. A self-signed one is fine for this purpose for now.
1. Create a Cloud DNS Zone  
This needs to be properly registered with your registar.
1. Grant `cloudbuild` IAM Role permissions  
As Cloud Build will be interacting with the load-balancer and Cloud DNS, the cloudbuild account needs permissions to do so.
1. Grant CertBot permissions to modidfy DNS records  
1. Setup a Cloud Build Trigger

### Create an HTTPS Load-balancer
In the console under Network Services > Load Balancing [here](https://console.cloud.google.com/net-services/loadbalancing/loadBalancers/list), create a new HTTPS Load Balancer.  
Follow the instructions and configure the backend services and frontend as needed for your setup.

If you need to create a temporary certificate, you can use openssl to self-sign a short-lived, bogus certifcate with this command:  
```
openssl req -new -newkey rsa:2048 -x509 -sha256 -days 7 -nodes -out cert.pem -keyout privkey.pem -subj "/C=US/CN=test.local"
```
If using the self-signed cert, you can skip the certificate chain requirement.

### Create a Cloud DNS Zone
In the console under Network Services > Cloud DNS [here](https://console.cloud.google.com/net-services/dns), create a new zone.  
Follow the instructions and additionally setup your registar to point to Google Cloud DNS for this new zone.  There is a link in the top right of the console 'Registar Setup' that has the values you'll need.

### Grant `cloudbuild` IAM Role permissions
In the console under IAM & Admin > IAM [here](https://console.cloud.google.com/iam-admin/iam), you should have a member for cloudbuild, something like `123456789@cloudbuild.gserviceaccount.com`.  
The member account should already have the `Cloud Build Service Account` role.  
To allow cloud build to modify the loadbalancer configuration, create the following custom role and add it to the cloud build service account.

Role: LoadBalancer certificate updates
```
compute.forwardingRules.list
compute.globalOperations.get
compute.sslCertificates.create
compute.sslCertificates.get
compute.sslCertificates.list
compute.targetHttpsProxies.get
compute.targetHttpsProxies.list
compute.targetHttpsProxies.setSslCertificates
```
You can do this in the console under IAM & Admin > Roles [here](https://console.cloud.google.com/iam-admin/roles)  
Add your new custom role to the cloudbuild member.

### Grant CertBot permissions to modify DNS records
In order to (separately) allow CertBot to alter the zone files in the process of DNS validation, we'll need the following addional role.

Role: CertBot DNS ownership validation
```
dns.changes.create
dns.changes.get
dns.managedZones.list
dns.resourceRecordSets.create
dns.resourceRecordSets.delete
dns.resourceRecordSets.list
dns.resourceRecordSets.update
```
While we should be able to just add the above role to the cloud build service account as well, a bug somewhere makes CertBot insensitve to such additions.
Instead we'll need to provide CertBot with an service account key explicitly, though a json file.
So, create a new service account, for example 'sa-certbot', and grant it the above role. Also generate a json key for it, this is what we'll use. 
The easiest way to provide the build system access to the key (security alert) is to include the json file directly into the (cloned) repository.
Note that this is a workaround, that may no longer be necessary in the near future, as the CertBot team could solve the 'insensitivity'.

### Setup a Cloud Build Trigger
In the console under Cloud Build > Build Triggers [here](https://console.cloud.google.com/cloud-build/triggers), create a new trigger.  
Point the trigger to your fork of this repo.  
> You might not need to fork, but it's recommended to be shielded from unwanted updates.  

Set the Build Configuration option to `cloudbuild.yaml` and add these additional variables.

> These are all required, and should be set to the names of the services and zones you created earlier.

| Variable | Example Value | Description |
| --- | --- | --- |
| _CACHE_BUCKET | my-cert-bucket | The name of the Google Cloud Storage bucket to use for storing/retrieving the certificates between builds |
| _EMAIL | me@example.com | The email that will be used when generating your letsencrypt certificates |
| _DOMAIN | example.com | The plain domain name for which certificates will be generated.  The configured zone must match this.  The request will be for a certificate that's valid for example.com and *.example.com |
| _FRONT_END_NAME_IPV4 | public-example-com-ipv4 | The name of the load balancer front-end for IP version 4, leave empty if not used |
| _FRONT_END_NAME_IPV6 | public-example-com-ipv6 | The name of the load balancer front-end for IP version 6, leave empty if not used |
| _SA_KEY_FILE | sa-certbot.json | Service account created to allow CertBot access to DNS zones, placed in this repostory |

If all works well, you should have a new certificate on your load-balancer after having run the trigger for the first time.  
The certificates will follow the naming pattern `zone-tld-certificate-serial` where any dots in the domain are replaced with dashes.  
Certificates will never be deleted, just removed from the load-balancer.  You can see all certificates in the console [here](https://console.cloud.google.com/net-services/loadbalancing/advanced/sslCertificates/list).

> NOTE: Remember to remove your temporary certificate from the https load-balancer.

## TODO
1. Setup a cron-style trigger so that certificates are checked for renewal each week(ish)