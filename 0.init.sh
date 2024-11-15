# This script copies the environment variables file to a local version, and generates a random storage name
cp 1.env.sh 1.env.$1.sh
sed -i "/export PROJECT_ID=/c\export PROJECT_ID=$1" 1.env.$1.sh