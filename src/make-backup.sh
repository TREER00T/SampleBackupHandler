##!/bin/bash
#
#SOURCE="/home/ali/CLionProjects/test/1c63e69996535ec328aa576e52b5c4a3"
#REMOTE_USER="root"
#REMOTE_HOST="87.248.152.231"
#REMOTE_PORT="9011"
#REMOTE_PATH="/root/data"
#FOLDER_NAME=$(basename "$SOURCE")
#PASSWORD="YJzih7wkb1"
#
#echo "🔍 Creating remote directory if not exists..."
#sshpass -p "$PASSWORD" ssh -p $REMOTE_PORT $REMOTE_USER@$REMOTE_HOST "mkdir -p $REMOTE_PATH/$FOLDER_NAME"
#
#echo "🔍 Getting list of files on server..."
#sshpass -p "$PASSWORD" ssh -p $REMOTE_PORT $REMOTE_USER@$REMOTE_HOST "find $REMOTE_PATH/$FOLDER_NAME -type f 2>/dev/null | sed 's|$REMOTE_PATH/$FOLDER_NAME/||'" > /tmp/remote_files_$$.txt
#
#cd "$SOURCE"
#
#echo "📋 Checking local files..."
#find . -type f | while read -r file; do
#    rel_path="${file#./}"
#
#    if ! grep -qxF "$rel_path" /tmp/remote_files_$$.txt 2>/dev/null; then
#        # Get directory path of the file
#        remote_subdir=$(dirname "$rel_path")
#
#        # Create subdirectory on remote if needed (and not current directory)
#        if [ "$remote_subdir" != "." ]; then
#            echo "   📁 Creating directory: $remote_subdir"
#            sshpass -p "$PASSWORD" ssh -p $REMOTE_PORT $REMOTE_USER@$REMOTE_HOST "mkdir -p $REMOTE_PATH/$FOLDER_NAME/$remote_subdir"
#        fi
#
#        echo "⬆️ Uploading: $rel_path"
#        sshpass -p "$PASSWORD" scp -P $REMOTE_PORT "$file" $REMOTE_USER@$REMOTE_HOST:$REMOTE_PATH/$FOLDER_NAME/$remote_subdir/
#
#        if [ $? -eq 0 ]; then
#            echo "   ✅ Success: $rel_path"
#        else
#            echo "   ❌ Error: $rel_path"
#        fi
#    else
#        echo "   ⏭️ Skipped (exists): $rel_path"
#    fi
#done
#
#rm -f /tmp/remote_files_$$.txt
#echo "✨ Done. New files uploaded."


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
