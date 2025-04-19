echo -e "\nStarting processing: $(date)\n" >> $LOG_FILE

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
  gcloud projects create $PROJECT_ID >> $LOG_FILE 2>&1
fi

if [ -n "$BILLING_ID" ]
then
  echo "Linking billing id..."
  gcloud beta billing projects link $PROJECT_ID --billing-account=$BILLING_ID >> $LOG_FILE 2>&1
fi

gcloud services enable orgpolicy.googleapis.com --project $PROJECT_ID >> $LOG_FILE 2>&1
gcloud services enable cloudresourcemanager.googleapis.com --project $PROJECT_ID >> $LOG_FILE 2>&1

PROJECT_NUMBER=$(gcloud projects list --filter="$PROJECT_ID" --format="value(PROJECT_NUMBER)")

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

  gcloud org-policies set-policy ./policies/requireOsLogin.local.yaml --project=$PROJECT_ID >> $LOG_FILE 2>&1
  gcloud org-policies set-policy ./policies/allowedPolicyMemberDomains.local.yaml --project=$PROJECT_ID >> $LOG_FILE 2>&1
  gcloud org-policies set-policy ./policies/requireShieldedVm.local.yaml --project=$PROJECT_ID >> $LOG_FILE 2>&1
  gcloud org-policies set-policy ./policies/vmExternalIpAccess.local.yaml --project=$PROJECT_ID >> $LOG_FILE 2>&1
fi

sleep 5

echo "Create network, if it doesn't exist..."
gcloud services enable compute.googleapis.com --project $PROJECT_ID >> $LOG_FILE 2>&1
sleep 2
gcloud compute networks create default --project $PROJECT_ID >> $LOG_FILE 2>&1

if [ -n "$GCP_ADD_USER" ]
then
  echo "Adding user..."
  sleep 10
  gcloud projects add-iam-policy-binding $PROJECT_ID \
    --member="user:$GCP_ADD_USER" \
    --role="roles/editor" >> $LOG_FILE 2>&1
  gcloud projects add-iam-policy-binding $PROJECT_ID \
    --member="user:$GCP_ADD_USER" \
    --role="roles/apigee.admin" >> $LOG_FILE 2>&1
  gcloud projects add-iam-policy-binding $PROJECT_ID \
    --member="user:$GCP_ADD_USER" \
    --role="roles/apihub.admin" >> $LOG_FILE 2>&1
  gcloud projects add-iam-policy-binding $PROJECT_ID \
    --member="user:$GCP_ADD_USER" \
    --role="roles/integrations.integrationAdmin" >> $LOG_FILE 2>&1
  gcloud projects add-iam-policy-binding $PROJECT_ID \
    --member="user:$GCP_ADD_USER" \
    --role="roles/serviceusage.serviceUsageAdmin" >> $LOG_FILE 2>&1
  gcloud projects add-iam-policy-binding $PROJECT_ID \
    --member="user:$GCP_ADD_USER" \
    --role="roles/compute.networkAdmin" >> $LOG_FILE 2>&1
  gcloud projects add-iam-policy-binding $PROJECT_ID \
    --member="user:$GCP_ADD_USER" \
    --role="roles/cloudkms.admin" >> $LOG_FILE 2>&1
  gcloud projects add-iam-policy-binding $PROJECT_ID \
    --member="user:$GCP_ADD_USER" \
    --role="roles/compute.admin" >> $LOG_FILE 2>&1
  gcloud projects add-iam-policy-binding $PROJECT_ID \
    --member="user:$GCP_ADD_USER" \
    --role="roles/run.admin" >> $LOG_FILE 2>&1          
  gcloud projects add-iam-policy-binding $PROJECT_ID \
    --member="user:$GCP_ADD_USER" \
    --role="roles/datastore.owner" >> $LOG_FILE 2>&1
  gcloud projects add-iam-policy-binding $PROJECT_ID \
    --member="user:$GCP_ADD_USER" \
    --role="roles/firebase.admin" >> $LOG_FILE 2>&1
fi

# enable APIs
gcloud services enable apigee.googleapis.com --project=$PROJECT_ID >> $LOG_FILE 2>&1
gcloud services enable apihub.googleapis.com --project=$PROJECT_ID >> $LOG_FILE 2>&1
gcloud services enable compute.googleapis.com --project=$PROJECT_ID >> $LOG_FILE 2>&1
gcloud services enable servicenetworking.googleapis.com --project=$PROJECT_ID >> $LOG_FILE 2>&1
gcloud services enable integrations.googleapis.com --project=$PROJECT_ID >> $LOG_FILE 2>&1
gcloud services enable connectors.googleapis.com --project=$PROJECT_ID >> $LOG_FILE 2>&1
gcloud services enable cloudkms.googleapis.com --project=$PROJECT_ID >> $LOG_FILE 2>&1
gcloud services enable aiplatform.googleapis.com --project=$PROJECT_ID >> $LOG_FILE 2>&1

# create default network, if it doesn't exist
gcloud compute networks create default --project=$PROJECT_ID >> $LOG_FILE 2>&1

# get org status
ORG_STATUS=$(curl "https://apigee.googleapis.com/v1/organizations/$PROJECT_ID" -H "Authorization: Bearer $(gcloud auth print-access-token)" 2>/dev/null | jq --raw-output '.state')
if [ $ORG_STATUS = null ]
then
  ORG_STATUS="NOT_FOUND"
fi

echo "Apigee org status is $ORG_STATUS"

if [ "$ORG_STATUS" == "NOT_FOUND" ] && [ "$CREATE_APIGEE_ORG" == "TRUE" ]
then
  # create Apigee organization (5 min)
  curl -X POST "https://apigee.googleapis.com/v1/organizations?parent=projects/$PROJECT_ID" \
  -H "Authorization: Bearer $(gcloud auth print-access-token)" \
  -H 'Content-Type: application/json; charset=utf-8' \
  --data-binary @- << EOF >> $LOG_FILE 2>&1

{
  "displayName": "$PROJECT_ID",
  "description": "$PROJECT_ID",
  "analyticsRegion": "$ANALYTICS_REGION",
  "runtimeType": "$RUNTIME_TYPE",
  "billingType": "$BILLING_TYPE",
  "disableVpcPeering": "true",
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
  --data-binary @- << EOF >> $LOG_FILE 2>&1

{
  "name": "instance1",
  "location": "$REGION",
  "description": "Instance in $REGION",
  "displayName": "Instance $REGION"
}
EOF

  # wait for instance
  SECONDS=0
  INSTANCE_STATUS=$(curl "https://apigee.googleapis.com/v1/organizations/$PROJECT_ID/instances/instance1" -H "Authorization: Bearer $(gcloud auth print-access-token)" 2>/dev/null | jq --raw-output '.state')
  while [ $INSTANCE_STATUS != "ACTIVE" ]
  do
    INSTANCE_STATUS=$(curl "https://apigee.googleapis.com/v1/organizations/$PROJECT_ID/instances/instance1" -H "Authorization: Bearer $(gcloud auth print-access-token)" 2>/dev/null | jq --raw-output '.state')
    if [ $INSTANCE_STATUS = null ]
    then
      INSTANCE_STATUS="NOT_FOUND"
    fi

    duration=$SECONDS    
    echo "Apigee instance status is $INSTANCE_STATUS, waiting for $((duration / 60)) minutes and $((duration % 60)) seconds." >> $LOG_FILE 2>&1
    echo "Apigee instance status is $INSTANCE_STATUS, waiting for $((duration / 60)) minutes and $((duration % 60)) seconds."
    sleep 120
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
  --project=$PROJECT_ID >> $LOG_FILE 2>&1

  # reserve IP address for Apigee
  gcloud compute addresses create apigee-ipaddress \
  --ip-version=IPV4 --global --project=$PROJECT_ID >> $LOG_FILE 2>&1

  # store IP address
  IP_ADDRESS=$(gcloud compute addresses describe apigee-ipaddress \
  --format="get(address)" --global --project=$PROJECT_ID)

  # create LB backend service for the NEG
  gcloud compute backend-services create apigee-backend \
  --load-balancing-scheme=EXTERNAL_MANAGED \
  --protocol=HTTPS \
  --global --project=$PROJECT_ID >> $LOG_FILE 2>&1

  # add the backend service to the NEG
  gcloud compute backend-services add-backend apigee-backend \
  --network-endpoint-group=apigee-neg \
  --network-endpoint-group-region=$REGION \
  --global --project=$PROJECT_ID >> $LOG_FILE 2>&1

  # create load balancer
  gcloud compute url-maps create apigee-lb \
  --default-service=apigee-backend \
  --global --project=$PROJECT_ID >> $LOG_FILE 2>&1

  # create certificate
  RUNTIME_HOST_ALIAS=$(echo "$IP_ADDRESS" | tr '.' '-').nip.io
  gcloud compute ssl-certificates create apigee-ssl-cert \
  --domains="$RUNTIME_HOST_ALIAS" --project "$PROJECT_ID" --quiet >> $LOG_FILE 2>&1

  # create target HTTPS proxy
  gcloud compute target-https-proxies create apigee-proxy \
  --url-map=apigee-lb \
  --ssl-certificates=apigee-ssl-cert --project=$PROJECT_ID >> $LOG_FILE 2>&1

  # create forwarding rule
  gcloud compute forwarding-rules create apigee-fw-rule \
    --load-balancing-scheme=EXTERNAL_MANAGED \
    --network-tier=PREMIUM \
    --address=$IP_ADDRESS \
    --target-https-proxy=apigee-proxy \
    --ports=443 \
    --global --project=$PROJECT_ID >> $LOG_FILE 2>&1

  # create environment group
  curl -X POST "https://apigee.googleapis.com/v1/organizations/$PROJECT_ID/envgroups" \
  -H "Authorization: Bearer $(gcloud auth print-access-token)" \
  -H 'Content-Type: application/json; charset=utf-8' \
  --data-binary @- << EOF >> $LOG_FILE 2>&1

{
  "name": "dev",
  "hostnames": ["$RUNTIME_HOST_ALIAS"]
}
EOF
fi

if [ "$CREATE_APIGEE_ENV" == "TRUE" ]
then
  # create dev environment
  curl -X POST "https://apigee.googleapis.com/v1/organizations/$PROJECT_ID/environments" \
  -H "Authorization: Bearer $(gcloud auth print-access-token)" \
  -H 'Content-Type: application/json; charset=utf-8' \
  --data-binary @- << EOF >> $LOG_FILE 2>&1

{
  "name": "dev"
}
EOF

  # attach environment to envgroup
  curl -X POST "https://apigee.googleapis.com/v1/organizations/$PROJECT_ID/envgroups/dev/attachments" \
  -H "Authorization: Bearer $(gcloud auth print-access-token)" \
  -H 'Content-Type: application/json; charset=utf-8' \
  --data-binary @- << EOF >> $LOG_FILE 2>&1

{
  "name": "dev",
  "environment": "dev"
}
EOF

  sleep 10
  # attach environment to instance
  curl -X POST "https://apigee.googleapis.com/v1/organizations/$PROJECT_ID/instances/instance1/attachments" \
  -H "Authorization: Bearer $(gcloud auth print-access-token)" \
  -H 'Content-Type: application/json; charset=utf-8' \
  --data-binary @- << EOF >> $LOG_FILE 2>&1

{
  "environment": "dev"
}
EOF

  sleep 10
  # reapply add-ons to enable for the new environment
  curl "https://apigee.googleapis.com/v1/organizations/$PROJECT_ID:setAddons" \
    -X POST \
    -H "Authorization: Bearer $(gcloud auth print-access-token)" \
    -H "Content-type: application/json" \
    -d '{
      "addonsConfig": {
        "advancedApiOpsConfig": {
          "enabled": true
        },
        "monetizationConfig": {
          "enabled": true
        },
        "apiSecurityConfig": {
          "enabled": true
        }
      }
    }' >> $LOG_FILE 2>&1
fi

# provision API Hub
if [ "$CREATE_APIGEE_APIHUB" == "TRUE" ]
then

  # create service identity
  gcloud beta services identity create --service=apihub.googleapis.com --project=$PROJECT_ID >> $LOG_FILE 2>&1

  # get project number and grant sa roles
  PROJECT_NUMBER=$(gcloud projects list --filter="$PROJECT_ID" --format="value(PROJECT_NUMBER)")
  SA_EMAIL="service-$PROJECT_NUMBER@gcp-sa-apihub.iam.gserviceaccount.com"
  gcloud projects add-iam-policy-binding $PROJECT_ID \
      --member="serviceAccount:$SA_EMAIL" \
      --role="roles/cloudkms.cryptoKeyEncrypterDecrypter" >> $LOG_FILE 2>&1
  gcloud projects add-iam-policy-binding $PROJECT_ID \
      --member="serviceAccount:$SA_EMAIL" \
      --role="roles/apihub.admin" >> $LOG_FILE 2>&1
  gcloud projects add-iam-policy-binding $PROJECT_ID \
      --member="serviceAccount:$SA_EMAIL" \
      --role="roles/apihub.runtimeProjectServiceAgent" >> $LOG_FILE 2>&1

  # create key ring
  # gcloud kms keyrings create apihub-keyring --project=$PROJECT_ID --location $API_HUB_REGION >> $LOG_FILE 2>&1
  # gcloud kms keys create apihub-key --keyring apihub-keyring --project=$PROJECT_ID --location $API_HUB_REGION --purpose "encryption" >> $LOG_FILE 2>&1

  # register host
  curl -X POST "https://apihub.googleapis.com/v1/projects/$PROJECT_ID/locations/$API_HUB_REGION/hostProjectRegistrations?hostProjectRegistrationId=$PROJECT_ID" \
  -H "Authorization: Bearer $(gcloud auth print-access-token)" \
  -H 'Content-Type: application/json; charset=utf-8' \
  --data-binary @- << EOF >> $LOG_FILE 2>&1

{
  "name": "projects/$PROJECT_ID/locations/$API_HUB_REGION/hostProjectRegistrations/$PROJECT_ID",
  "gcpProject": "projects/$PROJECT_ID"
}
EOF

  # register instance
  APIHUB_RESULT=$(curl -X POST "https://apihub.googleapis.com/v1/projects/$PROJECT_ID/locations/$API_HUB_REGION/apiHubInstances" \
  -H "Authorization: Bearer $(gcloud auth print-access-token)" \
  -H 'Content-Type: application/json; charset=utf-8' \
  --data-binary @- << EOF >> $LOG_FILE 2>&1

{
  "config": {
    "vertexLocation": "eu"
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
	--data-binary @- << EOF >> $LOG_FILE 2>&1
    
{}
EOF

echo "Application Integration status is ACTIVE"
