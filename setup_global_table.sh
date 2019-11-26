#!/bin/bash
# Three arguments required: target regions
if [ $# -ne 3 ]; then
  echo "Usage: $0 <table-name> <region-1> <region-2>"
  exit 1
fi

# Create the DynamoDB table in the origin region-1
result1=`aws dynamodb create-table \
    --table-name $1 \
    --attribute-definitions \
        AttributeName=item_id,AttributeType=S \
    --key-schema \
        AttributeName=item_id,KeyType=HASH \
    --provisioned-throughput \
        ReadCapacityUnits=5,WriteCapacityUnits=5 \
    --stream-specification StreamEnabled=true,StreamViewType=NEW_AND_OLD_IMAGES \
    --region $2 \
    --query 'TableDescription.{Status:TableStatus, arn:TableArn}'`

if [[ $result1 == *"CREATING"* ]]; then
  echo "Creating the DynamoDB table in "  $1 " in " $2
else 
  echo "Error when creating the DynamoDB table"
  exit 1
fi

# Create the DynamoDB table in the region-2
result2=`aws dynamodb create-table \
    --table-name $1 \
    --attribute-definitions \
        AttributeName=item_id,AttributeType=S \
    --key-schema \
        AttributeName=item_id,KeyType=HASH \
    --provisioned-throughput \
        ReadCapacityUnits=5,WriteCapacityUnits=5 \
    --stream-specification StreamEnabled=true,StreamViewType=NEW_AND_OLD_IMAGES \
    --region $3 \
    --query 'TableDescription.{Status:TableStatus, arn:TableArn}'`

if [[ $result2 == *"CREATING"* ]]; then
  echo "Creating the DynamoDB table in "  $1 " in " $3
else 
  echo "Error when creating the DynamoDB table"
  exit 1
fi

# Create the Global Table
result3=`aws dynamodb create-global-table \
    --global-table-name $1 \
    --replication-group RegionName=$2 RegionName=$3 \
    --region $2 \
    --query 'GlobalTableDescription.{Status:GlobalTableStatus, arn:GlobalTableArn}'`

if [[ $result3 == *"CREATING"* ]]; then
  echo "Creating the Global Table in "  $2 " and in " $3
else
  echo "Error when creating the global table"
  exit 1
fi