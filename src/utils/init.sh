#!/bin/bash

. "$1/utils/utils.sh"

# Check exist aws tools
if ! has_exist_command "aws"; then
	echo "${red}Error: aws dose not found"
	exit 1
fi

# Check if .env file exists
if [ -f "$1/.env" ]; then
	# Load variables from .env file
	. "$1/.env"
else
	echo "${red}Error: .env file not found."
	exit 1
fi

# Define the list of environment variable names
env_variables=(
	"ARCHIVE_MONGODB_PATH"
	"MONGODB_PASSWORD"
	"MONGODB_USERNAME"
	"STORAGE_PERIOD"
	"MONGODB_PORT"
	"ENDPOINT_URL"
	"PROJECT_NAME"
	"SCRIPT_PATH"
	"TARGET_PATH"
	"S3_BUCKET"
)

# Iterate through the list of environment variable names
for var_name in "${env_variables[@]}"; do
	# Check if the environment variable is set
	if [ -z "${!var_name}" ]; then
		echo "${yellow}Warning: $var_name is not set"
	fi
done
