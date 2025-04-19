# Apigee + Integration Quickstart
This is a quickstart for provisioning Apigee, API Hub & Application Integration in a new Google Cloud project.

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
- Initializes Apigee API Hub in the chosen region (1 min).
- Activates Application Integration in the chosen region (1 min).

After running this quickstart script, you can access Apigee, API Hub & Application Integration in the Google Cloud Console.

You can run this script very easily in [Google Cloud Shell](https://shell.cloud.google.com).

Set default values for the environment variables in the `1.env.sh` file.

```sh
# initialize variables in current shell
./0.init.sh YOUR_PROJECT_ID
# edit 1.env.YOUR_PROJECT_ID.sh, set parameters
source 1.env.YOUR_PROJECT_ID.sh

# provision, YOUR_PROJECT_ID will be created, if it doesn't exist
./2.provision.sh

# delete everything when you're finished
source 1.env.YOUR_PROJECT_ID.sh
./3.delete.sh
```