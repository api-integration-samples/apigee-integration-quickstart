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

1. After running step 1 below to create a new environment file, edit the new `1.env.YOUR_PROJECT_ID.sh` file with these main parameters (browse `1.env.sh` for full list):
  - REGION - the gcp & [apigee runtime region](https://cloud.google.com/apigee/docs/locations#available-apigee-runtime-regions) to deploy to, default is europe-west1.
  - ANALYTICS_REGION - the [apigee analytics region](https://cloud.google.com/apigee/docs/locations#available-apigee-api-analytics-regions), default is europe-west1.
  - BILLING_ID - set to your gcp billing id. If the project does not exist, it will be created with this billing id.
  - GCP_ADD_USER - a gcp user to add to the project, useful if you create the project with an admin user, and want to add a normal user automatically with default roles to work with the created resources (apigee, appint, etc).

```sh
# step 1 - copy base env file for a new project id, change to something unique
export PROJECT_ID=YOUR_PROJECT_ID
./0.init.sh $PROJECT_ID
# step 2 - edit new environment file, set parameters
nano 1.env.$PROJECT_ID.sh
# source variables
source 1.env.$PROJECT_ID.sh

# now do provisioning
./2.provision.sh
```