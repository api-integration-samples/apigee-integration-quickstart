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

# provision application integration
curl -X POST "https://integrations.googleapis.com/v1/projects/$PROJECT_ID/locations/$REGION/clients:provision" \
	-H "Authorization: Bearer $(gcloud auth print-access-token)" \
	-H "Content-Type: application/json" \
	--data-binary @- << EOF 1>/dev/null 2>/dev/null
    
{}
EOF

echo "Application Integration status is ACTIVE"