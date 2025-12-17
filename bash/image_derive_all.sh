#!/usr/bin/env bash

# This script reads a file containing all image styles that exist
# in prod and uses it to generate new image styles locally.

# Note: This must be called from inside the Drupal root.

FILENAME='/tmp/our-images.txt'
LOGFILE='/tmp/our-log.txt'

if [ ! -f "$FILENAME" ]; then
  echo "$FILENAME not found in $(pwd)"
  exit 1
fi

SECONDS=0;

cat $FILENAME | sed 's|^sites/default/files/styles/||' | awk '{ split($0, a, "/"); split($0, b, "/"); j = ""; for (i=3; i <= length(b); i++) { j = j "/" b[i]; } printf("drush image:derive %s \"public:/%s\"\n", a[1], j); }' | tr '\n' '\0' | xargs -P 10 -0 -I {} sh -c {} 2>&1 | tee $LOGFILE

# Display time elapsed and also write it to logfile.
printf "\n$SECONDS seconds\n" | tee -a $LOGFILE