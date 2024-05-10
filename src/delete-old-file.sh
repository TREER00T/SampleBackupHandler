#!/bin/bash

base_path=$(echo $1 | sed 's/.*=//')

. "$base_path/utils/init.sh" $base_path

aws s3 ls "s3://$S3_BUCKET" --endpoint-url $ENDPOINT_URL | while read -r line; do
	createDate=$(echo $line | awk {'print $1'})
	fileName=$(echo $line | awk {'print $4'})
	olderThan=$(date -d "$STORAGE_PERIOD days ago" +%s)
	fileDate=$(date -d $createDate +%s)
	if [[ $fileDate -lt $olderThan ]]; then
		if [[ $fileName != "" ]]; then
			aws s3 rm "s3://$S3_BUCKET/$fileName" --endpoint-url $ENDPOINT_URL
		fi
	fi
done
