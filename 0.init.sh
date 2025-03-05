# This script copies the environment variables file to a local version, and generates a random storage name
if [ ! -f 1.env.local.sh ]; then
  cp 1.env.sh 1.env.$1.sh
else
  cp 1.env.local.sh 1.env.$1.sh
fi

sed -i "/export PROJECT_ID=/c\export PROJECT_ID=$1" 1.env.$1.sh

source 1.env.$1.sh