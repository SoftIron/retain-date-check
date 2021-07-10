#!/bin/bash
# Takes IP of a Rados Gateway and checks the retain date format of an object with object lock

if [ "$1" == "-h" ] || [[ $# -eq 0 ]] ; then
  echo "Usage: `basename $0` RGW_IP"
  exit 0
fi

BUCKET_NAME=$(uuidgen | tail -c 10)
OBJECT_NAME=$(uuidgen | tail -c 10)
FILE_NAME="test_file.txt"
RGW_IP=$1

if [ $(dpkg-query -W -f='${Status}' curl 2>/dev/null | grep -c "ok installed") -eq 0 ];
then
  echo "Needs curl"
  exit 1
fi

echo "Testing Credentials"
TESTCREDS=$((aws s3api list-buckets --endpoint-url=http://$RGW_IP) 2>&1)
if [[ $TESTCREDS == *"InvalidAccessKeyId"* ]] || [[ $TESTCREDS == *"SignatureDoesNotMatch"* ]]; then
  echo "Credentials appear to be incorrect, check keys in ~/.aws/credentials"
  exit 1
else
  echo "OK."
fi

echo "Creating bucket $BUCKET_NAME"
aws s3api create-bucket --bucket=$BUCKET_NAME --endpoint-url=http://$RGW_IP --object-lock-enabled-for-bucket 

echo "Creating test file"
curl -s http://metaphorpsum.com/paragraphs/20 > $FILE_NAME

echo "Putting object"
PUT_OUTPUT=$(aws s3api put-object --bucket=$BUCKET_NAME --endpoint-url=http://$RGW_IP --key=$FILE_NAME --object-lock-retain-until-date "2021-08-08 14:00:00" --object-lock-mode COMPLIANCE)
echo $PUT_OUTPUT
VERSION_ID=`echo $PUT_OUTPUT | jq .VersionId`
echo "Object Version ID $VERSION_ID"

echo "Getting object metadata"
aws s3api head-object --bucket=$BUCKET_NAME --endpoint-url=http://$RGW_IP --key=$FILE_NAME

#echo "Deleting object"
#aws s3api delete-object --bucket=$BUCKET_NAME --endpoint-url=http://$RGW_IP --key=$FILE_NAME --version-id $VERSION_ID

#echo "Emptying bucket"
#aws s3 rm --recursive --endpoint-url=http://$RGW_IP s3://$BUCKET_NAME

echo "Deleting test file"
rm $FILE_NAME

echo "Listing buckets"
aws s3api list-buckets --endpoint-url=http://$RGW_IP

#echo "Deleting bucket $BUCKET_NAME"
#aws s3api delete-bucket --bucket=$BUCKET_NAME --endpoint-url=http://$RGW_IP
