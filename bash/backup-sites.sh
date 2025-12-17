
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

# Ensure rsync is available
if ! command -v rsync >/dev/null 2>&1; then
  echo "Error: rsync is not installed. Install with: sudo apt update && sudo apt install -y rsync" >&2
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
  if ! sudo rsync -a --delete "$dir" "$dest_dir/"; then
    rc=$?
    echo "Error: rsync failed for '$name' (source: $dir -> dest: $dest_dir/) with exit code $rc" >&2
    case "$rc" in
      10)
        echo "Hint: rsync exit code 10 usually indicates a socket I/O or connection problem (if using remote targets)." >&2
        echo "If you're backing up locally, check for disk or filesystem issues, NFS problems, or resource limits." >&2
        ;;
      11)
        echo "Hint: rsync exit code 11 indicates a file I/O error — check disk space and permissions." >&2
        ;;
      12)
        echo "Hint: rsync exit code 12 indicates protocol data stream errors — possible partial transfer or broken pipe." >&2
        ;;
      *)
        echo "Hint: see rsync manpage for exit code meanings: 'man rsync' or visit rsync.samba.org docs." >&2
        ;;
    esac
    exit "$rc"
  fi
done

echo "Corp Web Backup Complete"
echo "Drupal sites Backed up sir!"
