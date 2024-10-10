# Apigee + Integration Quickstart
This is a quickstart for provisioning Apigee & Application Integration in a new Google Cloud project.

As prerequisites you need:
- A Google Cloud project
- Your Google Cloud user needs to have these elevated roles or provision (or **Owner**)
  - **Apigee Organization Admin** (roles/apigee.admin)
  - **Application Integration** Admin (roles/integrations.integrationAdmin)
  - **Service Usage Admin** (roles/serviceusage.serviceUsageAdmin)
  - **Compute Network Admin** (roles/compute.networkAdmin)
  - **Cloud KMS Admin** (roles/cloudkms.admin)
  - **Compute Admin** (roles/compute.admin)

These actions are done in the project:
- Enables Apigee, Application Integration & related APIs in the project (1 min).
- Create a default network, if it does not exist (1 min).
- Creates an Apigee Org and waits until it is active, if it doesn't already exist (5 min).
- Creates an Apigee Instance in the chosen region and waits until it is active, if it doesn't already exist (30 min).
- Activates Application Integration in the chosen region (1 min).

After running this quickstart script, you can immediately start designing and deploying APIs & integrations in the chosen region.

## Instructions
You can run this script very easily in [Google Cloud Shell](https://shell.cloud.google.com).

```sh
# first copy the env file and add your project and region details
cp 1.env.sh 1.env.local.sh
# edit copied file and add project details
nano 1.env.local.sh
# source variables
source 1.env.local.sh

# now do provisioning
./2.provision.sh
```