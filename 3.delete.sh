if [ "$PROJECT_ID" = "" ]
then 
  echo "No Google Cloud project set, exiting... Add project details to 1.env.sh, run 'source 1.env.sh', and try again."
  exit
fi

gcloud projects delete $PROJECT_ID
