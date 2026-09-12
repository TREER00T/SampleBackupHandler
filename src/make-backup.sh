#!/bin/bash

base_path="${1#*=}"

. "$base_path/utils/init.sh" "$base_path"

filename=$(date +'%Y-%m-%d-%T-%N')
backup_path="$SCRIPT_PATH/${PROJECT_NAME:-Backup}-$filename.tar.gz"

simple_backup=true
stopped_containers=()

# --- Helper functions ---
create_tar() {
    echo "Creating backup archive..."
    if [ -f "$base_path/exclude.txt" ]; then
        tar -czvf "$backup_path" --exclude-from="$base_path/exclude.txt" "$TARGET_PATH" || return 1
    else
        tar -czvf "$backup_path" "$TARGET_PATH" || return 1
    fi
}

stop_containers() {
    echo "Stopping containers..."
    for c in "$@"; do
        [ -n "$c" ] && sudo docker stop "$c"
    done
    sleep 5
}

start_containers() {
    echo "Starting containers..."
    for c in "$@"; do
        [ -n "$c" ] && sudo docker start "$c"
    done
}

# --- Cleanup on exit ---
cleanup() {
    if [ ${#stopped_containers[@]} -gt 0 ]; then
        echo "Restarting containers after interruption..."
        start_containers "${stopped_containers[@]}"
        stopped_containers=()
    fi
}
trap cleanup EXIT

# --- MongoDB Backup ---
if [ -n "$MONGODB_DOCKER_NAME" ]; then
    if sudo docker ps -a --format '{{.Names}}' | grep -q "^$MONGODB_DOCKER_NAME$"; then
        simple_backup=false

        echo "Taking MongoDB backup..."
        sudo docker exec "$MONGODB_DOCKER_NAME" mongodump \
            --verbose \
            --archive="$ARCHIVE_MONGODB_PATH" \
            --authenticationDatabase admin \
            --port "$MONGODB_PORT" \
            -u "$MONGODB_USERNAME" \
            -p "$MONGODB_PASSWORD" || { echo "${red}mongodump failed${reset}"; exit 1; }

        stopped_containers=("$MONGODB_DOCKER_NAME" "$SECOND_CONTAINER")
        stop_containers "${stopped_containers[@]}"

        create_tar || { echo "${red}tar failed${reset}"; exit 1; }

        start_containers "${stopped_containers[@]}"
        stopped_containers=()
    else
        echo "${yellow}Warning: MongoDB container '$MONGODB_DOCKER_NAME' not found${reset}"
    fi
fi

# --- MySQL + WordPress Backup ---
if [ -n "$MYSQL_DOCKER_NAME" ] && [ -n "$WORDPRESS_DOCKER_NAME" ]; then
    if [ "$simple_backup" = false ]; then
        # fix #1: MongoDB already took the backup, skip MySQL to avoid overwrite
        echo "${yellow}Warning: MongoDB backup already taken this run, skipping MySQL${reset}"
    else
        simple_backup=false

        echo "Taking MySQL backup..."
        sudo docker exec "$MYSQL_DOCKER_NAME" mysqldump \
            -u "$MYSQL_USER" -p"$MYSQL_PASSWORD" \
            --databases "$MYSQL_DATABASE" > "$ARCHIVE_MYSQL_PATH" || { echo "${red}mysqldump failed${reset}"; exit 1; }

        stopped_containers=("$WORDPRESS_DOCKER_NAME" "$MYSQL_DOCKER_NAME" "$SECOND_CONTAINER")
        stop_containers "${stopped_containers[@]}"

        create_tar || { echo "${red}tar failed${reset}"; exit 1; }

        start_containers "${stopped_containers[@]}"
        stopped_containers=()
    fi
fi

# --- Simple backup (no database) ---
if [ "$simple_backup" = true ]; then
    create_tar || { echo "${red}tar failed${reset}"; exit 1; }
fi

# --- Upload backup ---
if bash "$base_path/upload-file.sh" "$1" "$backup_path"; then
    rm -f "$backup_path"
else
    echo "${red}Upload failed. Local backup kept at: $backup_path${reset}"
    exit 1
fi

trap - EXIT
