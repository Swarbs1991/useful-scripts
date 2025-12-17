
#!/usr/bin/env bash
# Drupal permissions & Apache setup script
# Tested on Ubuntu + Apache 2 (www-data), Drupal 9/10 layout.
# It is safe to re-run; it won't break if run multiple times.

set -euo pipefail

### ============
### CONFIGURE ME
### ============
APACHE_USER="www-data"
DEV_GROUP="devs"



# Line 16 — prompt and validate
while true; do
  read -rp "Enter the project path (e.g., /var/www/example): " PROJECT_ROOT
  if [[ -d "$PROJECT_ROOT" ]]; then
    break
  else
    echo "The path '$PROJECT_ROOT' does not exist. Please try again."
  fi
done

WEBROOT="${PROJECT_ROOT}/webroot"         # vhost DocumentRoot points here
SITE_DIR="${WEBROOT}/sites/default"       # change if you use multisite
FILES_DIR="${SITE_DIR}/files"
PRIVATE_DIR="${SITE_DIR}/private"         # optional; created if you use private files

### ============
### SANITY CHECKS
### ============
if [[ ! -d "${PROJECT_ROOT}" ]]; then
  echo "ERROR: PROJECT_ROOT does not exist: ${PROJECT_ROOT}" >&2
  exit 1
fi
if [[ ! -d "${WEBROOT}" ]]; then
  echo "ERROR: WEBROOT does not exist: ${WEBROOT}" >&2
  exit 1
fi

# Ensure dev group exists
if ! getent group "${DEV_GROUP}" >/dev/null; then
  echo "Creating group ${DEV_GROUP}..."
  groupadd "${DEV_GROUP}"
fi

# Ensure Apache user exists
if ! id "${APACHE_USER}" >/dev/null 2>&1; then
  echo "ERROR: Apache user '${APACHE_USER}' not found." >&2
  exit 1
fi

echo "Using PROJECT_ROOT=${PROJECT_ROOT}"
echo "Using WEBROOT=${WEBROOT}"
echo "Using SITE_DIR=${SITE_DIR}"
echo "Using FILES_DIR=${FILES_DIR}"
echo

### ================================================================
### 1) PROJECT ROOT: root-owned, devs group, traverse for Apache
### ================================================================
echo ">> Setting ownership & perms for PROJECT_ROOT..."
chown -R root:"${DEV_GROUP}" "${PROJECT_ROOT}"

# Allow developers to read/write; allow Apache to traverse into webroot only
chmod 751 "${PROJECT_ROOT}"   # x for others to allow traversal; no read for others
# Keep code/group writable (devs), no world access
find "${PROJECT_ROOT}" -type d -not -path "${WEBROOT}" -exec chmod 750 {} \;
# .git lockdown (devs can read/write; Apache cannot)
if [[ -d "${PROJECT_ROOT}/.git" ]]; then
  chmod 770 "${PROJECT_ROOT}/.git"
fi

### ================================================================
### 2) WEBROOT: owned by Apache + devs, setgid for group inheritance
### ================================================================
echo ">> Setting ownership & perms for WEBROOT..."
chown -R "${APACHE_USER}":"${DEV_GROUP}" "${WEBROOT}"

# Directories: group-writable (devs), Apache can read/execute; inherit group via setgid
find "${WEBROOT}" -type d -exec chmod 775 {} \;
find "${WEBROOT}" -type d -exec chmod g+s {} \;

# Files: group-writable (devs), readable by Apache
# Avoid making scripts executable; PHP doesn’t need +x
find "${WEBROOT}" -type f -not -path "${FILES_DIR}/*" -exec chmod 664 {} \;

### ================================================================
### 3) DRUPAL FILES DIR: Apache must read/write; devs too; setgid + ACL
### ================================================================
echo ">> Ensuring FILES_DIR exists and is writable by Apache + devs..."
mkdir -p "${FILES_DIR}"
chown -R "${APACHE_USER}":"${DEV_GROUP}" "${FILES_DIR}"
find "${FILES_DIR}" -type d -exec chmod 775 {} \;
find "${FILES_DIR}" -type d -exec chmod g+s {} \;
find "${FILES_DIR}" -type f -exec chmod 664 {} \;

# Optional: private files dir (if used)
if [[ ! -d "${PRIVATE_DIR}" ]]; then
  mkdir -p "${PRIVATE_DIR}"
fi
chown -R "${APACHE_USER}":"${DEV_GROUP}" "${PRIVATE_DIR}"
find "${PRIVATE_DIR}" -type d -exec chmod 770 {} \;   # tighter perms
find "${PRIVATE_DIR}" -type d -exec chmod g+s {} \;

# Extra resilience: ACLs so Apache keeps rwx even if ownership changes later
if command -v setfacl >/dev/null 2>&1; then
  echo ">> Applying ACLs to ${FILES_DIR} (and default ACLs for new content)..."
  setfacl -R -m u:"${APACHE_USER}":rwx "${FILES_DIR}"
  setfacl -d -m u:"${APACHE_USER}":rwx "${FILES_DIR}"
fi

### ================================================================
### 4) settings.php hardening: Apache read, devs write, others none
### ================================================================
SETTINGS_PHP="${SITE_DIR}/settings.php"
if [[ -f "${SETTINGS_PHP}" ]]; then
  echo ">> Hardening settings.php..."
  chown "${APACHE_USER}":"${DEV_GROUP}" "${SETTINGS_PHP}"
  chmod 640 "${SETTINGS_PHP}"   # Apache reads; devs write; others none
else
  echo "NOTE: ${SETTINGS_PHP} not found (skipping)."
fi

### ================================================================
### 5) Developer umask: keep files group-writable for devs
### ================================================================
echo ">> Configuring dev umask (002) for members of ${DEV_GROUP}..."
cat >/etc/profile.d/devs-umask.sh <<'EOF'
# Apply umask 002 to keep group write for devs, without affecting non-dev users
if id -nG 2>/dev/null | tr ' ' '\n' | grep -qx 'devs'; then
  umask 002
fi
EOF
chmod 644 /etc/profile.d/devs-umask.sh

### ================================================================
### 6) Apache hardening & access: Directory + .git deny
### ================================================================
echo ">> Installing Apache config snippet for Drupal hardening..."
cat >/etc/apache2/conf-available/drupal-hardening.conf <<EOF
# Allow access to the webroot
<Directory "${WEBROOT}">
    AllowOverride All
    Require all granted
    Options FollowSymLinks
</Directory>

# Deny access to VCS directories anywhere under DocumentRoot
<DirectoryMatch "^.*/\.git">
    Require all denied
</DirectoryMatch>
<DirectoryMatch "^.*/\.svn">
    Require all denied
</DirectoryMatch>
<DirectoryMatch "^.*/\.hg">
    Require all denied
</DirectoryMatch>

# (Optional) If you use a private files path under the webroot, deny direct HTTP access:
<Directory "${PRIVATE_DIR}">
    Require all denied
</Directory>
EOF

a2enconf drupal-hardening >/dev/null || true

echo ">> Testing Apache config..."
apache2ctl configtest

echo ">> Restarting Apache..."
systemctl restart apache2

### ================================================================
### Diagnostics: common 403 causes
### ================================================================
echo
echo ">> Diagnostics:"
echo " - Try listing as Apache user:"
sudo -u "${APACHE_USER}" ls -lah "${WEBROOT}" || true

echo
echo ">> AppArmor / SELinux status (if enabled):"
command -v aa-status >/dev/null 2>&1 && aa-status || echo "AppArmor not installed."
command -v getenforce >/dev/null 2>&1 && getenforce || echo "SELinux not installed."

echo
echo "All done."
echo "If you still see 403s, check:"
echo "  * Parent dirs of ${PROJECT_ROOT} have +x so Apache can traverse."
echo "  * The vhost's DocumentRoot points to ${WEBROOT}."
echo "  * No .htaccess rules are denying access."
echo "  * AppArmor profile for apache2 permits ${WEBROOT}."
