if [ "$PROJECT_ID" = "" ]
then 
  echo "No Google Cloud project set, exiting... Add project details to 1.env.sh, run 'source 1.env.sh', and try again."
  exit
fi

PROJECT_STATUS=$(gcloud projects describe $PROJECT_ID --format="value(lifecycleState)" 2>/dev/null)
if [ "$PROJECT_STATUS" = "" ]
then
  PROJECT_STATUS="NOT_FOUND"
fi
echo "Project status for $PROJECT_ID is $PROJECT_STATUS"

if [ "$PROJECT_STATUS" == "NOT_FOUND" ]
then
  echo "Creating project..."
  gcloud projects create $PROJECT_ID

  if [ -n "$BILLING_ID" ]
  then
    echo "Linking billing id..."
    gcloud beta billing projects link $PROJECT_ID --billing-account=$BILLING_ID
  fi

  gcloud config set project $PROJECT_ID

  gcloud services enable orgpolicy.googleapis.com
  gcloud services enable cloudresourcemanager.googleapis.com

  sleep 5

  echo "Setting organizational policy configuration..."
  PROJECT_NUMBER=$(gcloud projects list --filter="$(gcloud config get-value project)" --format="value(PROJECT_NUMBER)")
  echo "Found project number $PROJECT_NUMBER"

  if [ -n "$PROJECT_NUMBER" ]
  then
    cp policies/requireOsLogin.yaml policies/requireOsLogin.local.yaml
    cp policies/allowedPolicyMemberDomains.yaml policies/allowedPolicyMemberDomains.local.yaml
    cp policies/requireShieldedVm.yaml policies/requireShieldedVm.local.yaml
    cp policies/vmExternalIpAccess.yaml policies/vmExternalIpAccess.local.yaml

    sed -i "s@{PROJECTNUMBER}@$PROJECT_NUMBER@" policies/requireOsLogin.local.yaml
    sed -i "s@{PROJECTNUMBER}@$PROJECT_NUMBER@" policies/allowedPolicyMemberDomains.local.yaml
    sed -i "s@{PROJECTNUMBER}@$PROJECT_NUMBER@" policies/requireShieldedVm.local.yaml
    sed -i "s@{PROJECTNUMBER}@$PROJECT_NUMBER@" policies/vmExternalIpAccess.local.yaml

    gcloud org-policies set-policy ./policies/requireOsLogin.local.yaml --project=$PROJECT_ID
    gcloud org-policies set-policy ./policies/allowedPolicyMemberDomains.local.yaml --project=$PROJECT_ID
    gcloud org-policies set-policy ./policies/requireShieldedVm.local.yaml --project=$PROJECT_ID
    gcloud org-policies set-policy ./policies/vmExternalIpAccess.local.yaml --project=$PROJECT_ID
  fi

  echo "Create network, if it doesn't exist..."
  gcloud services enable compute.googleapis.com
  gcloud compute networks create default

  if [ -n "$GCP_ADD_USER" ]
  then
      echo "Adding user..."
      sleep 5
      gcloud projects add-iam-policy-binding $PROJECT_ID \
          --member="user:$GCP_ADD_USER" \
          --role="roles/editor"
      gcloud projects add-iam-policy-binding $PROJECT_ID \
          --member="user:$GCP_ADD_USER" \
          --role="roles/apigee.admin"
      gcloud projects add-iam-policy-binding $PROJECT_ID \
          --member="user:$GCP_ADD_USER" \
          --role="roles/apihub.admin"
      gcloud projects add-iam-policy-binding $PROJECT_ID \
          --member="user:$GCP_ADD_USER" \
          --role="roles/integrations.integrationAdmin"
      gcloud projects add-iam-policy-binding $PROJECT_ID \
          --member="user:$GCP_ADD_USER" \
          --role="roles/serviceusage.serviceUsageAdmin"
      gcloud projects add-iam-policy-binding $PROJECT_ID \
          --member="user:$GCP_ADD_USER" \
          --role="roles/compute.networkAdmin"
      gcloud projects add-iam-policy-binding $PROJECT_ID \
          --member="user:$GCP_ADD_USER" \
          --role="roles/cloudkms.admin"
      gcloud projects add-iam-policy-binding $PROJECT_ID \
          --member="user:$GCP_ADD_USER" \
          --role="roles/compute.admin"
  fi
fi

# set project
gcloud config set project $PROJECT_ID 1>/dev/null 2>/dev/null

# enable APIs
gcloud services enable apigee.googleapis.com
gcloud services enable apihub.googleapis.com
gcloud services enable compute.googleapis.com
gcloud services enable servicenetworking.googleapis.com
gcloud services enable integrations.googleapis.com
gcloud services enable connectors.googleapis.com
gcloud services enable cloudkms.googleapis.com
gcloud services enable aiplatform.googleapis.com

# create default network
gcloud compute networks create default 1>/dev/null 2>/dev/null

# get org status
ORG_STATUS=$(curl "https://apigee.googleapis.com/v1/organizations/$PROJECT_ID" -H "Authorization: Bearer $(gcloud auth print-access-token)" 2>/dev/null | jq --raw-output '.state')
if [ $ORG_STATUS = null ]
then
  ORG_STATUS="NOT_FOUND"
fi

echo "Apigee org status is $ORG_STATUS"

if [ "$ORG_STATUS" == "NOT_FOUND" ] && [ "$CREATE_APIGEE_ORG" == "TRUE" ]
then

  # prepare networking if VPC peering selected
  if [ "$DISABLE_VPC_PEERING" == "false" ]
  then
    gcloud compute addresses create apigee-range \
      --global \
      --prefix-length=22 \
      --description="Peering range for Apigee services" \
      --network=$NETWORK \
      --purpose=VPC_PEERING \
      --project=$PROJECT_ID

    gcloud compute addresses create google-managed-services-support-1 \
      --global \
      --prefix-length=28 \
      --description="Peering range for supporting Apigee services" \
      --network=$NETWORK \
      --purpose=VPC_PEERING \
      --project=$PROJECT_ID

    gcloud services vpc-peerings connect \
      --service=servicenetworking.googleapis.com \
      --network=$NETWORK \
      --ranges=apigee-range,google-managed-services-support-1 \
      --project=$PROJECT_ID

    # create Apigee VPC peering organization (5 min)
    curl -X POST "https://apigee.googleapis.com/v1/organizations?parent=projects/$PROJECT_ID" \
    -H "Authorization: Bearer $(gcloud auth print-access-token)" \
    -H 'Content-Type: application/json; charset=utf-8' \
    --data-binary @- << EOF 1>/dev/null 2>/dev/null

{
  "displayName": "$PROJECT_ID",
  "description": "$PROJECT_ID",
  "analyticsRegion": "$ANALYTICS_REGION",
  "authorizedNetwork": "$NETWORK_NAME",
  "runtimeType": "$RUNTIME_TYPE",
  "billingType": "$BILLING_TYPE",
  "disableVpcPeering": "$DISABLE_VPC_PEERING",
  "addonsConfig": {
    "monetizationConfig": {
      "enabled": "true"
    },
    "advancedApiOpsConfig": {
      "enabled": true
    },
    "apiSecurityConfig": {
      "enabled": true
    }
  },
  "state": "ACTIVE",
  "portalDisabled": true
}
EOF
  else
    # create Apigee non-peering organization (5 min)
    curl -X POST "https://apigee.googleapis.com/v1/organizations?parent=projects/$PROJECT_ID" \
    -H "Authorization: Bearer $(gcloud auth print-access-token)" \
    -H 'Content-Type: application/json; charset=utf-8' \
    --data-binary @- << EOF 1>/dev/null 2>/dev/null

{
  "displayName": "$PROJECT_ID",
  "description": "$PROJECT_ID",
  "analyticsRegion": "$ANALYTICS_REGION",
  "runtimeType": "$RUNTIME_TYPE",
  "billingType": "$BILLING_TYPE",
  "disableVpcPeering": "$DISABLE_VPC_PEERING",
  "addonsConfig": {
    "monetizationConfig": {
      "enabled": "true"
    },
    "advancedApiOpsConfig": {
      "enabled": true
    },
    "apiSecurityConfig": {
      "enabled": true
    }
  },
  "state": "ACTIVE",
  "portalDisabled": true
}
EOF
  fi

  # get org status
  ORG_STATUS=$(curl "https://apigee.googleapis.com/v1/organizations/$PROJECT_ID" -H "Authorization: Bearer $(gcloud auth print-access-token)" 2>/dev/null | jq --raw-output '.state')

  while [ $ORG_STATUS != "ACTIVE" ]
  do
    ORG_STATUS=$(curl "https://apigee.googleapis.com/v1/organizations/$PROJECT_ID" -H "Authorization: Bearer $(gcloud auth print-access-token)" 2>/dev/null | jq --raw-output '.state')
    sleep 3
  done

  echo "Apigee org status is $ORG_STATUS"
fi

INSTANCE_STATUS=$(curl "https://apigee.googleapis.com/v1/organizations/$PROJECT_ID/instances/instance1" -H "Authorization: Bearer $(gcloud auth print-access-token)" 2>/dev/null | jq --raw-output '.state')
if [ $INSTANCE_STATUS = null ]
then
  INSTANCE_STATUS="NOT_FOUND"
fi
echo "Apigee instance status is $INSTANCE_STATUS"

if [ "$INSTANCE_STATUS" == "NOT_FOUND" ] && [ "$CREATE_APIGEE_INSTANCE" == "TRUE" ]
then
  # create instance (30 min)
  curl -X POST "https://apigee.googleapis.com/v1/organizations/$PROJECT_ID/instances" \
  -H "Authorization: Bearer $(gcloud auth print-access-token)" \
  -H 'Content-Type: application/json; charset=utf-8' \
  --data-binary @- << EOF 1>/dev/null 2>/dev/null

{
  "name": "instance1",
  "location": "$REGION",
  "description": "Instance in $REGION",
  "displayName": "Instance $REGION"
}
EOF

  # wait for instance
  INSTANCE_STATUS=$(curl "https://apigee.googleapis.com/v1/organizations/$PROJECT_ID/instances/instance1" -H "Authorization: Bearer $(gcloud auth print-access-token)" 2>/dev/null | jq --raw-output '.state')
  while [ $INSTANCE_STATUS != "ACTIVE" ]
  do
    INSTANCE_STATUS=$(curl "https://apigee.googleapis.com/v1/organizations/$PROJECT_ID/instances/instance1" -H "Authorization: Bearer $(gcloud auth print-access-token)" 2>/dev/null | jq --raw-output '.state')
    sleep 60
  done

  echo "Apigee instance status is $INSTANCE_STATUS"
fi

if [ "$CREATE_APIGEE_LB" == "TRUE" ]
then
  # get service attachment url
  TARGET_SERVICE=$(curl "https://apigee.googleapis.com/v1/organizations/$PROJECT_ID/instances/instance1" \
  -H "Authorization: Bearer $(gcloud auth print-access-token)" 2>/dev/null | jq --raw-output '.serviceAttachment')

  # create a Private Service Connect NEG that points to the service attachment
  gcloud compute network-endpoint-groups create apigee-neg \
  --network-endpoint-type=private-service-connect \
  --psc-target-service=$TARGET_SERVICE \
  --region=$REGION \
  --project=$PROJECT_ID 2>/dev/null

  # reserve IP address for Apigee
  gcloud compute addresses create apigee-ipaddress \
  --ip-version=IPV4 --global --project=$PROJECT_ID 2>/dev/null

  # store IP address
  IP_ADDRESS=$(gcloud compute addresses describe apigee-ipaddress \
  --format="get(address)" --global --project=$PROJECT_ID)

  # create LB backend service for the NEG
  gcloud compute backend-services create apigee-backend \
  --load-balancing-scheme=EXTERNAL_MANAGED \
  --protocol=HTTPS \
  --global --project=$PROJECT_ID 2>/dev/null 1>/dev/null

  # add the backend service to the NEG
  gcloud compute backend-services add-backend apigee-backend \
  --network-endpoint-group=apigee-neg \
  --network-endpoint-group-region=$REGION \
  --global --project=$PROJECT_ID 2>/dev/null 1>/dev/null

  # create load balancer
  gcloud compute url-maps create apigee-lb \
  --default-service=apigee-backend \
  --global --project=$PROJECT_ID 2>/dev/null 1>/dev/null

  # create certificate
  RUNTIME_HOST_ALIAS=$(echo "$IP_ADDRESS" | tr '.' '-').nip.io
  gcloud compute ssl-certificates create apigee-ssl-cert \
  --domains="$RUNTIME_HOST_ALIAS" --project "$PROJECT_ID" --quiet 2>/dev/null 1>/dev/null

  # create target HTTPS proxy
  gcloud compute target-https-proxies create apigee-proxy \
  --url-map=apigee-lb \
  --ssl-certificates=apigee-ssl-cert --project=$PROJECT_ID 2>/dev/null 1>/dev/null

  # create forwarding rule
  gcloud compute forwarding-rules create apigee-fw-rule \
    --load-balancing-scheme=EXTERNAL_MANAGED \
    --network-tier=PREMIUM \
    --address=$IP_ADDRESS \
    --target-https-proxy=apigee-proxy \
    --ports=443 \
    --global --project=$PROJECT_ID 2>/dev/null 1>/dev/null

  # create environment group
  curl -X POST "https://apigee.googleapis.com/v1/organizations/$PROJECT_ID/envgroups" \
  -H "Authorization: Bearer $(gcloud auth print-access-token)" \
  -H 'Content-Type: application/json; charset=utf-8' \
  --data-binary @- << EOF 2>/dev/null 1>/dev/null

{
  "name": "dev",
  "hostnames": ["$RUNTIME_HOST_ALIAS"]
}
EOF
fi

if [ "$CREATE_APIGEE_ENV" == "TRUE" ]
then
  # create environment
  curl -X POST "https://apigee.googleapis.com/v1/organizations/$PROJECT_ID/environments" \
  -H "Authorization: Bearer $(gcloud auth print-access-token)" \
  -H 'Content-Type: application/json; charset=utf-8' \
  --data-binary @- << EOF 2>/dev/null 1>/dev/null

{
  "name": "dev"
}
EOF

  # attach environment to envgroup
  curl -X POST "https://apigee.googleapis.com/v1/organizations/$PROJECT_ID/envgroups/dev/attachments" \
  -H "Authorization: Bearer $(gcloud auth print-access-token)" \
  -H 'Content-Type: application/json; charset=utf-8' \
  --data-binary @- << EOF 2>/dev/null 1>/dev/null

{
  "name": "dev",
  "environment": "dev"
}
EOF

  # attach environment to instance
  curl -X POST "https://apigee.googleapis.com/v1/organizations/$PROJECT_ID/instances/instance1/attachments" \
  -H "Authorization: Bearer $(gcloud auth print-access-token)" \
  -H 'Content-Type: application/json; charset=utf-8' \
  --data-binary @- << EOF 2>/dev/null 1>/dev/null

{
  "environment": "dev"
}
EOF
fi

# provision API Hub
if [ "$CREATE_APIGEE_APIHUB" == "TRUE" ]
then

  # create service identity
  gcloud beta services identity create --service=apihub.googleapis.com --project=$PROJECT_ID

  # get project number and grant sa roles
  PROJECT_NUMBER=$(gcloud projects list --filter="$(gcloud config get-value project)" --format="value(PROJECT_NUMBER)")
  SA_EMAIL="service-$PROJECT_NUMBER@gcp-sa-apihub.iam.gserviceaccount.com"
  gcloud projects add-iam-policy-binding $PROJECT_ID \
      --member="serviceAccount:$SA_EMAIL" \
      --role="roles/cloudkms.cryptoKeyEncrypterDecrypter"
  gcloud projects add-iam-policy-binding $PROJECT_ID \
      --member="serviceAccount:$SA_EMAIL" \
      --role="roles/apihub.admin"
  gcloud projects add-iam-policy-binding $PROJECT_ID \
      --member="serviceAccount:$SA_EMAIL" \
      --role="roles/apihub.runtimeProjectServiceAgent"

  # create key ring
  gcloud kms keyrings create apihub-keyring --project=$PROJECT_ID --location $API_HUB_REGION
  gcloud kms keys create apihub-key --keyring apihub-keyring --project=$PROJECT_ID --location $API_HUB_REGION --purpose "encryption"

  # register host
  curl -X POST "https://apihub.googleapis.com/v1/projects/$PROJECT_ID/locations/$API_HUB_REGION/hostProjectRegistrations?hostProjectRegistrationId=$PROJECT_ID" \
  -H "Authorization: Bearer $(gcloud auth print-access-token)" \
  -H 'Content-Type: application/json; charset=utf-8' \
  --data-binary @- << EOF 2>/dev/null 1>/dev/null

{
  "name": "projects/$PROJECT_ID/locations/$API_HUB_REGION/hostProjectRegistrations/$PROJECT_ID",
  "gcpProject": "projects/$PROJECT_ID"
}
EOF

  APIHUB_RESULT=$(curl -X POST "https://apihub.googleapis.com/v1/projects/$PROJECT_ID/locations/$API_HUB_REGION/apiHubInstances?apiHubInstanceId=apihub1" \
  -H "Authorization: Bearer $(gcloud auth print-access-token)" \
  -H 'Content-Type: application/json; charset=utf-8' \
  --data-binary @- << EOF 2>/dev/null

{
  "name": "projects/$PROJECT_ID/locations/$API_HUB_REGION/apiHubInstances/apihub1",
  "config": {
    "cmekKeyName": "projects/$PROJECT_ID/locations/$API_HUB_REGION/keyRings/apihub-keyring/cryptoKeys/apihub-key"
  }
}
EOF
  )

  echo "API Hub status is ACTIVE"
fi

# provision application integration
curl -X POST "https://integrations.googleapis.com/v1/projects/$PROJECT_ID/locations/$REGION/clients:provision" \
	-H "Authorization: Bearer $(gcloud auth print-access-token)" \
	-H "Content-Type: application/json" \
	--data-binary @- << EOF 1>/dev/null 2>/dev/null
    
{}
EOF

echo "Application Integration status is ACTIVE"

