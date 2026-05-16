# 💾 FTP Website Backup Download Script 📦

[🇬🇧 Read in English](README.md) | [🇫🇷 Lire en Français](README_FR.md)

This bash script downloads website and database backup archives from an FTP server, and manages local archive retention by deleting archives that are too old while keeping a minimum number of backups.

## 🌟 Features

- 📥 Download of website and database archives from an FTP server.
- 📝 Logging of download operations and actions taken.
- 🗑️ Deletion of old archives based on configurable criteria, using the date embedded in the archive filename.
- 🔒 Guaranteed retention of a minimum number of archives, even if they exceed the age limit.
- 📂 Automatic creation of backup and log directories if needed.
- ✅ Success verification for each operation with error handling.

## 📋 Prerequisites

- `wget` must be installed on your machine.
- Access to an FTP server containing the website and database archives.
- Archives on the FTP server must contain a date in `YYYY-MM-DD` format in their filename.

## 🛠️ Usage

1. Clone this repository or download the script.
2. Edit the variables at the top of the script to configure your FTP server details, backup paths, and archive retention criteria.
3. Make the script executable: `chmod +x script_backup_client.sh`
4. Run it manually or schedule it via a cron job.

### ⏰ Cron Job Example

To run the script every day at 3:00 AM (after server-side backup generation):

```bash
0 3 * * * /path/to/script_backup_client.sh
```

## 🔧 Variables to Configure

- `USER`: FTP account username on the server.
- `PASSWORD`: FTP account password on the server.
- `SERVER`: FTP server address.
- `BACKUP_PATH`: Path to the directory where backups will be stored locally.
- `LOGS_PATH`: Path to the directory where logs will be saved.
- `DAYS_OLD`: Number of days after which archives become candidates for deletion (default: 60 days).
- `MIN_ARCHIVES`: Minimum number of archives to keep per site, even if they exceed `DAYS_OLD` (default: 4 archives).

## 📝 Script Example

```bash
#!/bin/bash

# Variables
USER="exemple@yourdomaine.com"
PASSWORD="FTP_PASSWORD"
SERVER="ftp.exemple.com"
BACKUP_PATH="/path/to/backup/folder"
DATE=$(date +"%Y-%m-%d")
LOGS_PATH="/path/to/logs"
DAYS_OLD=60   # Number of days before archives are candidates for deletion
MIN_ARCHIVES=4 # Minimum number of archives to keep

# Logging function (defined first)
log() {
  local message=$1
  echo "$(date '+%Y-%m-%d %H:%M:%S') - $message" >>"$LOGS_PATH/${DATE}_script_backup_logs"
}

# Check if the logs directory exists
if [ ! -d "$LOGS_PATH" ]; then
  echo "$(date '+%Y-%m-%d %H:%M:%S') - Logs directory $LOGS_PATH does not exist. Creating it..."
  mkdir -p "$LOGS_PATH"
fi

# Function to download archives for a site and its corresponding database
download_site_and_db() {
  local site=$1
  local db=${SITES_DBS[$site]}

  # Create the local backup directory for the site if it doesn't exist
  if [ ! -d "${BACKUP_PATH}/${site}" ]; then
    log "[INFO] Creating backup directory for site $site."
    mkdir -p "${BACKUP_PATH}/${site}"
  fi

  if [ -n "$site" ]; then
    log "[INFO] Downloading archive for site $site"
    wget ftp://${SERVER}/site_${site}* --ftp-user=${USER} --ftp-password=${PASSWORD} -P ${BACKUP_PATH}/${site}
    if [ $? -eq 0 ]; then
      log "[SUCCESS] Archive download for site $site complete"
    else
      log "[ERROR] Archive download failed for site $site."
    fi
  fi

  if [ -n "$db" ]; then
    log "[INFO] Downloading archive for database $db"
    wget ftp://${SERVER}/bdd_${db}* --ftp-user=${USER} --ftp-password=${PASSWORD} -P ${BACKUP_PATH}/${site}
    if [ $? -eq 0 ]; then
      log "[SUCCESS] Archive download for database $db complete"
    else
      log "[ERROR] Archive download failed for database $db."
    fi
  else
    log "[WARNING] No associated database found for site $site"
  fi
}

# Function to delete old archives based on the date in the filename
cleaning_archives_old() {
  local site=$1
  log "[INFO] Deleting archives older than $DAYS_OLD days for $site (min retention: $MIN_ARCHIVES)"

  local backup_dir="${BACKUP_PATH}/${site}"

  # List files containing a YYYY-MM-DD date in their name, sorted newest to oldest
  local all_archives
  mapfile -t all_archives < <(
    find "$backup_dir" -maxdepth 1 -type f \
    | grep -E '[0-9]{4}-[0-9]{2}-[0-9]{2}' \
    | sort -r
  )

  local total=${#all_archives[@]}
  log "[INFO] $total archive(s) found for $site"

  if [ "$total" -eq 0 ]; then
    log "[INFO] No archives found for $site"
    return
  fi

  local today
  today=$(date +%s)
  local deleted=0
  local skipped=0

  for i in "${!all_archives[@]}"; do
    local file="${all_archives[$i]}"
    local filename
    filename=$(basename "$file")

    # Extract the YYYY-MM-DD date from the filename
    local file_date
    file_date=$(echo "$filename" | grep -oE '[0-9]{4}-[0-9]{2}-[0-9]{2}' | head -1)

    if [ -z "$file_date" ]; then
      log "[WARNING] Could not extract date from: $filename — skipped"
      continue
    fi

    # Calculate the file age in days
    local file_epoch
    file_epoch=$(date -d "$file_date" +%s 2>/dev/null)

    if [ -z "$file_epoch" ]; then
      log "[WARNING] Invalid date '$file_date' in: $filename — skipped"
      continue
    fi

    local age_days=$(( (today - file_epoch) / 86400 ))

    # Always keep the top $MIN_ARCHIVES most recent archives (index 0 to MIN_ARCHIVES-1)
    if [ "$i" -lt "$MIN_ARCHIVES" ]; then
      log "[INFO] Kept (top $MIN_ARCHIVES): $filename ($age_days d)"
      (( skipped++ ))
      continue
    fi

    # Delete if older than $DAYS_OLD days
    if [ "$age_days" -gt "$DAYS_OLD" ]; then
      log "[INFO] Deleting: $filename ($age_days d > $DAYS_OLD d)"
      if rm -f "$file"; then
        log "[SUCCESS] Deleted: $filename"
        (( deleted++ ))
      else
        log "[ERROR] Deletion failed: $filename"
      fi
    else
      log "[INFO] Kept (recent): $filename ($age_days d)"
      (( skipped++ ))
    fi
  done

  log "[INFO] Summary for $site — Deleted: $deleted | Kept: $skipped"
}

# Define sites and their corresponding databases
# Left side "exemplesite01.com" is the name of the compressed archive containing the website files
# Right side "db_site01" is the name of the compressed archive containing the database dump
declare -A SITES_DBS=(
  ["exemplesite01.com"]="db_site01"
  ["exemplesite02.com"]="db_site02"
  ["exemplesite03.com"]="db_site03"
  ["exemplesite04.com"]="" # Example: Leave empty if the site has no database
  ["exemplesite05.com"]="db_site05"
  ["exemplesite06.com"]="db_site06"
)

# For each site:
# Download the archives and their corresponding databases
# Delete archives older than $DAYS_OLD days while keeping a minimum of $MIN_ARCHIVES
for site in "${!SITES_DBS[@]}"; do
  log "========================================================================================"
  log "Starting processing for site $site"
  log "========================================================================================"
  download_site_and_db "$site"
  cleaning_archives_old "$site"
  log "========================================================================================"
  log "Processing complete for site $site."
  log "========================================================================================"
  log ""
done
```

## 📖 Function Explanations

### 📝 log Function
Defined first in the script. Logs a timestamped message to the daily log file.

```bash
log() {
  local message=$1
  echo "$(date '+%Y-%m-%d %H:%M:%S') - $message" >>"$LOGS_PATH/${DATE}_script_backup_logs"
}
```

### 📁 Directory Check and Creation
Checks whether the log directory exists and creates it if necessary. Each site's backup directory is created on the fly inside `download_site_and_db`.

```bash
if [ ! -d "$LOGS_PATH" ]; then
  echo "$(date '+%Y-%m-%d %H:%M:%S') - Logs directory $LOGS_PATH does not exist. Creating it..."
  mkdir -p "$LOGS_PATH"
fi
```

### 📥 download_site_and_db Function
Downloads the site and database archives from the FTP server. Creates the local backup directory if needed, and verifies the success of each download.

```bash
download_site_and_db() {
  local site=$1
  local db=${SITES_DBS[$site]}

  if [ ! -d "${BACKUP_PATH}/${site}" ]; then
    log "[INFO] Creating backup directory for site $site."
    mkdir -p "${BACKUP_PATH}/${site}"
  fi

  wget ftp://${SERVER}/site_${site}* --ftp-user=${USER} --ftp-password=${PASSWORD} -P ${BACKUP_PATH}/${site}

  if [ $? -eq 0 ]; then
    log "[SUCCESS] Archive download for site $site complete"
  else
    log "[ERROR] Archive download failed for site $site."
  fi
  # ...
}
```

### 🧹 cleaning_archives_old Function
Deletes old archives for each site based on the `YYYY-MM-DD` date found in the filename. Always keeps at least `$MIN_ARCHIVES` recent archives, and only deletes files exceeding `$DAYS_OLD` days. Logs a full summary at the end.

```bash
cleaning_archives_old() {
  local site=$1

  # Sort archives newest to oldest using the date in their filename
  mapfile -t all_archives < <(
    find "$backup_dir" -maxdepth 1 -type f \
    | grep -E '[0-9]{4}-[0-9]{2}-[0-9]{2}' \
    | sort -r
  )

  for i in "${!all_archives[@]}"; do
    # Always keep the MIN_ARCHIVES most recent archives
    if [ "$i" -lt "$MIN_ARCHIVES" ]; then continue; fi

    # Delete if older than DAYS_OLD days
    if [ "$age_days" -gt "$DAYS_OLD" ]; then
      rm -f "$file"
    fi
  done
  # ...
}
```

### 🔗 Association Map
Defines an associative array that maps each website to its database. If a site has no database, the value is left empty.

```bash
declare -A SITES_DBS=(
  ["exemplesite01.com"]="db_site01"
  ["exemplesite02.com"]="db_site02"
  ["exemplesite03.com"]="db_site03"
  ["exemplesite04.com"]="" # Example: Leave empty if the site has no database
  ["exemplesite05.com"]="db_site05"
  ["exemplesite06.com"]="db_site06"
)
```

### 🔄 Backup Processing Loop
Iterates over all sites defined in the `SITES_DBS` associative array, downloads their corresponding archives, then deletes old archives while guaranteeing a minimum retention.

```bash
for site in "${!SITES_DBS[@]}"; do
  log "========================================================================================"
  log "Starting processing for site $site"
  log "========================================================================================"
  download_site_and_db "$site"
  cleaning_archives_old "$site"
  log "========================================================================================"
  log "Processing complete for site $site."
  log "========================================================================================"
  log ""
done
```

## 🗂️ Expected Archive Format

This script expects archives whose filenames contain a date in `YYYY-MM-DD` format, compatible with archives produced by the associated server script:

| Type | Expected format | Example |
|---|---|---|
| Database | `bdd_{db_name}_{YYYY-MM-DD}.sql.gz` | `bdd_db_site01_2025-01-15.sql.gz` |
| Website | `site_{site_name}_{YYYY-MM-DD}.tgz` | `site_exemplesite01.com_2025-01-15.tgz` |

## 🔗 Associated Server Script

This client script works in tandem with the **server script** available in this repository: [[script-backup-site](https://github.com/MikaPST/script-backup-site)].

The server script is responsible for:
- Generating database dumps via `mysqldump`.
- Archiving website files via `tar`.
- Placing the archives on the FTP server for this script to retrieve.

## 📜 License
This script is licensed under the **MIT License**.

## 🤝 Contributing
Contributions are welcome! Feel free to open an issue or submit a pull request.
