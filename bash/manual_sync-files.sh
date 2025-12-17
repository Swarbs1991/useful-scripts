#!/bin/bash

# Define the servers and directories
servers=("10.200.19.36" "10.200.19.20")
file_path=="/var/www/html/testsync"

# rsync options
rsync_opts="-avz --update --owner --group"

# Function to sync files between local and remote servers
sync_with_server() {
    local target_server=$1
    echo "Syncing with $target_server..."

    # Pull newer files from remote server to local
    rsync $rsync_opts $target_server:$file_path/ $file_path/

    # Push newer files from local to remote server
    rsync $rsync_opts $file_path/ $target_server:$file_path/
}

# Loop through each server and sync files
for server in "${servers[@]}"; do
    if [[ "$(hostname)" != "$server" ]]; then
        sync_with_server "$server"
    fi
done

echo "File synchronization completed."

