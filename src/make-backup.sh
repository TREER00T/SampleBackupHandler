#!/bin/bash
set -euo pipefail

base_path=$(echo "$1" | sed 's/.*=//')

# shellcheck source=/dev/null
. "$base_path/utils/init.sh" "$base_path"

# Colors in case they aren't defined
yellow="${yellow:-\033[33m}"
reset="${reset:-\033[0m}"

filename=$(date +'%Y-%m-%d-%T-%N')
backup_path="$SCRIPT_PATH/${PROJECT_NAME:-Backup}-$filename.tar.gz"

simple_backup=true
containers_to_restart=()

# Helper function for tar
create_tar() {
    echo "Creating backup archive..."
    if [ -f "$base_path/exclude.txt" ]; then
        tar -czvf "$backup_path" --exclude-from="$base_path/exclude.txt" "$TARGET_PATH"
    else
        tar -czvf "$backup_path" "$TARGET_PATH"
    fi
}

# Helper function for safe restart
restart_containers() {
    for c in "${containers_to_restart[@]}"; do
        echo "Starting container: $c"
        sudo docker start "$c" || true
    done
    containers_to_restart=()
}

# On error, restart the containers
trap 'restart_containers' EXIT

# --- MongoDB Backup ---
if [ -n "${MONGODB_DOCKER_NAME:-}" ]; then
    mongodb_name="$MONGODB_DOCKER_NAME"

    if sudo docker ps -a --format '{{.Names}}' | grep -q "^${mongodb_name}$"; then
        simple_backup=false

        echo "Taking MongoDB backup..."
        sudo docker exec "$mongodb_name" mongodump \
            --verbose \
            --archive="$ARCHIVE_MONGODB_PATH" \
            --authenticationDatabase admin \
            --port "$MONGODB_PORT" \
            -u "$MONGODB_USERNAME" \
            -p "$MONGODB_PASSWORD"

        echo "Stopping MongoDB container..."
        sudo docker stop "$mongodb_name"
        containers_to_restart+=("$mongodb_name")

        if [ -n "${SECOND_CONTAINER:-}" ]; then
            sudo docker stop "$SECOND_CONTAINER"
            containers_to_restart+=("$SECOND_CONTAINER")
        fi

        sleep 5
        create_tar

        restart_containers
    else
        echo -e "${yellow}Warning: MongoDB container '$mongodb_name' not found${reset}"
    fi
fi

# --- MySQL + WordPress Backup ---
if [ -n "${MYSQL_DOCKER_NAME:-}" ] && [ -n "${WORDPRESS_DOCKER_NAME:-}" ]; then
    mysql_name="$MYSQL_DOCKER_NAME"
    wordpress_name="$WORDPRESS_DOCKER_NAME"

    # Prevent duplicate backup if MongoDB was also active
    if [ "$simple_backup" = false ]; then
        echo -e "${yellow}Warning: Both MongoDB and MySQL backups are configured."
        echo -e "Only one database backup per run is supported. Skipping MySQL.${reset}"
    else
        simple_backup=false

        echo "Taking MySQL backup..."
        sudo docker exec "$mysql_name" mysqldump \
            -u "$MYSQL_USER" -p"$MYSQL_PASSWORD" \
            --databases "$MYSQL_DATABASE" > "$ARCHIVE_MYSQL_PATH"

        echo "Stopping WordPress and MySQL containers..."
        sudo docker stop "$wordpress_name"
        containers_to_restart+=("$wordpress_name")
        sudo docker stop "$mysql_name"
        containers_to_restart+=("$mysql_name")

        if [ -n "${SECOND_CONTAINER:-}" ]; then
            sudo docker stop "$SECOND_CONTAINER"
            containers_to_restart+=("$SECOND_CONTAINER")
        fi

        sleep 5
        create_tar

        restart_containers
    fi
fi

# --- Simple backup (no database) ---
if [ "$simple_backup" = true ]; then
    create_tar
fi

# --- Upload backup ---
bash "$base_path/upload-file.sh" "$1" "$backup_path"

# --- Remove local backup ---
rm -f "$backup_path"

# Disable the trap since the work is done
trap - EXIT
