#!/bin/bash

base_path=$(echo $1 | sed 's/.*=//')

. "$base_path/utils/init.sh" $base_path

filename=$(date +'%Y-%m-%d-%T-%N')
backup_path="$SCRIPT_PATH/${PROJECT_NAME:-Backup}-$filename.tar.gz"

# --- MongoDB Backup ---
if [ -n "$MONGODB_DOCKER_NAME" ]; then
    mongodb_name="$MONGODB_DOCKER_NAME"

    if sudo docker ps -a --format '{{.Names}}' | grep -q "^$mongodb_name$"; then
        echo "Taking MongoDB backup..."
        sudo docker exec $mongodb_name mongodump \
            --verbose \
            --archive=$ARCHIVE_MONGODB_PATH \
            --authenticationDatabase admin \
            --port $MONGODB_PORT \
            -u $MONGODB_USERNAME \
            -p $MONGODB_PASSWORD

        echo "Stopping MongoDB container..."
        sudo docker stop $mongodb_name

        if [[ -n "$SECOND_CONTAINER" ]]; then
          sudo docker stop $SECOND_CONTAINER
        fi

        sleep 5

        # Tar backup
        echo "Creating WordPress + DB backup..."
        if [ -f "$base_path/exclude.txt" ]; then
            tar -czvf $backup_path --exclude-from="$base_path/exclude.txt" $TARGET_PATH
        else
            tar -czvf $backup_path $TARGET_PATH
        fi

        echo "Starting MongoDB container..."
        sudo docker start $mongodb_name

        if [[ -n "$SECOND_CONTAINER" ]]; then
          sudo docker start $SECOND_CONTAINER
        fi
    else
        echo "${yellow}Warning: MongoDB container '$mongodb_name' not found"
    fi
fi

# --- MySQL + WordPress Backup ---
if [ -n "$MYSQL_DOCKER_NAME" ] && [ -n "$WORDPRESS_DOCKER_NAME" ]; then
    mysql_name="$MYSQL_DOCKER_NAME"
    wordpress_name="$WORDPRESS_DOCKER_NAME"

    # MySQL Dump
    echo "Taking MySQL backup..."
    sudo docker exec $mysql_name mysqldump \
        -u $MYSQL_USER -p$MYSQL_PASSWORD \
        --databases $MYSQL_DATABASE > "$ARCHIVE_MYSQL_PATH"

    if [[ -n "$SECOND_CONTAINER" ]]; then
      sudo docker stop $SECOND_CONTAINER
    fi

    # Stop containers
    echo "Stopping WordPress and MySQL containers..."
    sudo docker stop $wordpress_name
    sudo docker stop $mysql_name

    sleep 5

    # Tar backup
    echo "Creating WordPress + DB backup..."
    if [ -f "$base_path/exclude.txt" ]; then
        tar -czvf $backup_path --exclude-from="$base_path/exclude.txt" $TARGET_PATH
    else
        tar -czvf $backup_path $TARGET_PATH
    fi

    # Start containers
    echo "Starting WordPress and MySQL containers..."
    sudo docker start $mysql_name
    sudo docker start $wordpress_name

    if [[ -n "$SECOND_CONTAINER" ]]; then
      sudo docker start $SECOND_CONTAINER
    fi
else
    echo "${yellow}Warning: MySQL or WordPress container names not set in env"
fi

# --- Upload backup ---
bash "$base_path/upload-file.sh" $1 $backup_path

# --- Remove local backup ---
rm $backup_path
