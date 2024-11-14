# your gcp project id
export PROJECT_ID=
export LOG_FILE="$PROJECT_ID.log.txt"
# europe-west1, europe-west2, europe-west3, europe-west4, europe-west6 - https://cloud.google.com/apigee/docs/locations#available-apigee-runtime-regions
export REGION=
# europe-west1, europe-west2, europe-west4, europe-west6 - https://cloud.google.com/apigee/docs/locations#available-apigee-api-analytics-regions
export ANALYTICS_REGION=
# us-central1, europe-west1
export API_HUB_REGION=
# CLOUD, HYBRID, RUNTIME_TYPE_UNSPECIFIED
export RUNTIME_TYPE=
# EVALUATION, SUBSCRIPTION, PAYG
export BILLING_TYPE=
# your billing id (optional)
export BILLING_ID=
# a user to add to the project (optional)
export GCP_ADD_USER=

# Create Apigee Org TRUE or FALSE
export CREATE_APIGEE_ORG=FALSE
# Create Apigee Instance TRUE or FALSE
export CREATE_APIGEE_INSTANCE=FALSE
# Create Apigee LB TRUE or FALSE
export CREATE_APIGEE_LB=FALSE
# Create Apigee Environment & Group TRUE or FALSE
export CREATE_APIGEE_ENV=FALSE
# Create Apigee API Hub TRUE or FALSE
export CREATE_APIGEE_APIHUB=FALSE