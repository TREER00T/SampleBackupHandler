#!/bin/bash

base_path=$(echo $1 | sed 's/.*=//')

. "$base_path/utils/init.sh" $base_path

filename=$(date +'%Y-%m-%d-%T-%N')
backup_path="$SCRIPT_PATH/$filename.tar.gz"

mongodb_name="${MONGODB_DOCKER_NAME:-mongo}"

# Check if the mongo container exists
if sudo docker ps -a --format '{{.Names}}' | grep -q "^$mongodb_name$"; then
	# If the container exists, execute mongodump
	sudo docker exec $mongodb_name mongodump \
		--verbose \
		--archive=$ARCHIVE_MONGODB_PATH \
		--authenticationDatabase admin \
		--port $MONGODB_PORT \
		-u $MONGODB_USERNAME \
		-p $MONGODB_PASSWORD
else
	# If the container doesn't exist, print an error message
	echo "${yellow}Warning: 'mongo' docker container does not exist Or mongodb container have different name, Set MONGODB_DOCKER_NAME env on exclude.txt file"
fi

if [ -f "$base_path/exclude.txt" ]; then
	tar -czvf $backup_path --exclude-from="$base_path/exclude.txt" $TARGET_PATH
else
	tar -czvf $backup_path $TARGET_PATH
fi

bash "$base_path/upload-file.sh" $1 $backup_path

rm $backup_path
