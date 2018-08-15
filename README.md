# gcp-letsencrypt
Cloudbuild script to obtain and renew certificates and attach to a load-balancer in Google Cloud Platform.
This can be run in [Google Cloud Build](https://cloud.google.com/cloud-build/).

This is intended to be used to renew [letsencrypt](https://letsencrypt.org) certificates (or get certificates for a new domain) and set them to be used on an *existing* [https load-balancer](https://cloud.google.com/load-balancing/docs/https/).  
Without edits, this will try to obtain a wildcard certificate for the whole domain, including the domain apex.

> Note: This script stores the generated certificates in Google Cloud Storage between runs to avoid renewing certificates too frequently.  This may pose a security risk.

### Getting Started
There are some prerequsites to using this script, asside from having a Google Cloud account.

1. An existing https load-balancer.  
You'll need a certificate pair in order to create the load-balancer. A self-signed one is fine for this purpose for now.
1. An existing Cloud DNS zone.  
This needs to be properly registered with your registar.
1. cloudbuild IAM account needs additional permissions.  
As Cloud Build will be interacting with the load-balancer and Cloud DNS, the cloudbuild account needs permissiosn to do so.

#### Create an HTTPS Load-balancer
In the console under Network Services > Load Balancing [here](https://console.cloud.google.com/net-services/loadbalancing/loadBalancers/list), create a new HTTPS Load Balancer.  
Follow the instructions and configure the backend services and frontend as needed for your setup.

If you need to create a temporary certificate, you can use openssl to self-sign a short-lived, bogus certifcate with this command:  
```
openssl req -new -newkey rsa:2048 -x509 -sha256 -days 7 -nodes -out cert.pem -keyout privkey.pem -subj "/C=US/CN=test.local"
```
If using the self-signed cert, you can skip the certificate chain requirement.

#### Create a Cloud DNS zone
In the console under Network Services > Cloud DNS [here](https://console.cloud.google.com/net-services/dns), create a new zone.  
Follow the instructions and additionally setup your registar to point to Google Cloud DNS for this new zone.  There is a link in the top right of the console 'Registar Setup' that has the values you'll need.

#### Grant cloudbuild IAM Role permissions
In the console under IAM & Admin > IAM [here](https://console.cloud.google.com/iam-admin/iam), you should have a member for cloudbuild, something like `123456789@cloudbuild.gserviceaccount.com`.  To get started quickly, edit this member to add additional course-grained roles.  
The member account should already have the `Cloud Build Service Account` role.  
Additionally give it these roles:  
```
Compute Network Admin
DNS Administrator
```

> Note: You may want to grant more finely-grained permissions rather than these general roles.

#### Setup a Cloud Build Trigger
