gcloud config set project $PROJECT_ID 1>/dev/null 2>/dev/null

# enable APIs
gcloud services enable apigee.googleapis.com
gcloud services enable apihub.googleapis.com
gcloud services enable compute.googleapis.com
gcloud services enable servicenetworking.googleapis.com
gcloud services enable integrations.googleapis.com
gcloud services enable connectors.googleapis.com

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
  # create Apigee organization (5 min)
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

# provision application integration
curl -X POST "https://integrations.googleapis.com/v1/projects/$PROJECT_ID/locations/$REGION/clients:provision" \
	-H "Authorization: Bearer $(gcloud auth print-access-token)" \
	-H "Content-Type: application/json" \
	--data-binary @- << EOF 1>/dev/null 2>/dev/null
    
{}
EOF

echo "Application Integration status is ACTIVE"