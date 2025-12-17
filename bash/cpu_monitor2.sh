#!/bin/bash

# Get the average CPU usage
CPU=$(sar 1 5 | awk '/Average/ {print $NF}')

# Check if the sar command was successful
if [ $? -ne 0 ]; then
    echo "Error: sar command failed."
    exit 1
fi

# Compare CPU usage and take action
if [ "$CPU" -gt 70 ]; then
    cat mail_content.html | /usr/lib/sendmail -t
else
    echo "Normal"
fi
