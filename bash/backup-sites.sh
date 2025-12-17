
#!/usr/bin/env bash
set -euo pipefail

SRC="/var/www/html"
DEST="$SRC/site-backups"

echo "Backing up sites from $SRC to $DEST"

# Ensure destination exists (may require sudo)
sudo mkdir -p "$DEST"

# Explicitly prompt for sudo password now (and fail fast if not allowed)
sudo -k
if ! sudo -v; then
  echo "Error: sudo authentication failed. Cannot proceed with backup." >&2
  exit 1
fi

# Loop through directories in /var/www/html, skipping site-backups
for dir in "$SRC"/*/; do
  # Skip if no directories found
  [ -d "$dir" ] || continue

  name="$(basename "$dir")"
  if [[ "$name" == "site-backups" ]]; then
    continue
  fi

  dest_dir="$DEST/$name"
  echo "? Backing up $name to $dest_dir ..."
  # Create the target subfolder (in case it doesn't exist yet)
  sudo mkdir -p "$dest_dir"

  # Use trailing slash on source to copy contents into the target subfolder
  # This results in: /var/www/html/site-backups/<name>/(contents of <name>)
  sudo rsync -a --delete "$dir" "$dest_dir/"
done

echo "Corp Web Backup Complete"
echo "Drupal sites Backed up sir!"
