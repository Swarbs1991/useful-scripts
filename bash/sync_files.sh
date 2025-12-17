#!/bin/bash

# Set the directory to monitor
WATCH_DIR="/var/www/html/corptest/web/sites/default/files"

# Remote servers and target directories
REMOTE1="swarbrickj@10.200.19.36:/var/www/html/corpdev/web/sites/default/files"
#REMOTE2="user@remote2:/path/to/web/sites/default/files"

# Ensure inotify-tools is installed
if ! command -v inotifywait &> /dev/null; then
    echo "Error: inotifywait is not installed. Install it with: sudo apt-get install inotify-tools"
    exit 1
fi

# Function to sync the directory to both servers
sync_files() {
    rsync -avz "$WATCH_DIR/" $REMOTE1
    if [ $? -ne 0 ]; then
        echo "Error syncing to $REMOTE1"
    fi
    
    # rsync -avz --delete "$WATCH_DIR/" $REMOTE2
    # if [ $? -ne 0 ]; then
    #     echo "Error syncing to $REMOTE2"
    # fi
}

# Monitor the directory for changes
echo "Monitoring $WATCH_DIR for changes..."
inotifywait -m -e create -e modify -e delete -e move "$WATCH_DIR" --format '%w%f' | while read FILE; do
    echo "Detected change in $FILE"
    sync_files
done
