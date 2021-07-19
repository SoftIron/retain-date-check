#!/bin/bash
# Takes S3 endpoint and checks the retain date format of an object with object lock

if [ "$1" == "-h" ] || [[ $# -eq 0 ]] ; then
  echo "Usage: `basename $0` RGW_IP"
  exit 0
fi

BUCKET_NAME=$(uuidgen | tail -c 10)
DATE=$(date "+%Y-%m-%d %H:%M:%S" -d "+1 month")
FILE_NAME="test_file.txt"
RGW_IP=$1

for pkg in curl awscli; do
  if [ $(dpkg-query -W -f='${Status}' $pkg 2>/dev/null | grep -c "ok installed") -eq 0 ];
  then
    echo "Needs $pkg"
    exit 1
  fi
done

echo "Testing Credentials"
TESTCREDS=$((aws s3api list-buckets --endpoint-url=http://$RGW_IP) 2>&1)
if [[ $TESTCREDS == *"InvalidAccessKeyId"* ]] || [[ $TESTCREDS == *"SignatureDoesNotMatch"* ]]; then
  echo "Credentials appear to be incorrect, check keys in ~/.aws/credentials"
  exit 1
elif [[ $TESTCREDS == *"No such file or directory"* ]] || [[ $TESTCREDS == *"command not found"* ]]; then
  echo "awscli doesn't appear to be installed - maybe try apt install awcli?"
  exit 1
elif [[ $TESTCREDS == *"Unable to locate credentials"* ]]; then
  echo "~/.aws/credentials file not configured correctly"
  exit 1
elif [[ $TESTCREDS == *"Could not connect to the endpoint"* ]]; then
  echo "RGW appears to be down"
  exit 1
else
  echo "OK."
fi

echo "Creating bucket $BUCKET_NAME"
aws s3api create-bucket --bucket=$BUCKET_NAME --endpoint-url=http://$RGW_IP --object-lock-enabled-for-bucket 

echo "Creating test file"
curl -s http://metaphorpsum.com/paragraphs/20 > $FILE_NAME

echo "Putting object"
PUT_OUTPUT=$(aws s3api put-object --bucket=$BUCKET_NAME --endpoint-url=http://$RGW_IP --key=$FILE_NAME --object-lock-retain-until-date "$DATE" --object-lock-mode COMPLIANCE)
echo $PUT_OUTPUT
VERSION_ID=`echo $PUT_OUTPUT | jq .VersionId`
echo "Object Version ID $VERSION_ID"

echo "Getting object metadata"
aws s3api head-object --bucket=$BUCKET_NAME --endpoint-url=http://$RGW_IP --key=$FILE_NAME

echo "Deleting test file"
rm $FILE_NAME

echo "Listing buckets"
aws s3api list-buckets --endpoint-url=http://$RGW_IP
