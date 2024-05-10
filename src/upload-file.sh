#!/bin/bash

base_path=$(echo $1 | sed 's/.*=//')

. "$base_path/utils/init.sh" $base_path

filename=$(basename "$2")

# Upload back file to S3
aws s3 cp "$2" "s3://$S3_BUCKET/$filename" --endpoint-url $ENDPOINT_URL
