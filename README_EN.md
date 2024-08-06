# 💾 FTP Download Script for Website Backup Archives 📦

[🇫🇷 Lire en Français](README.md) | [🇬🇧 Read in English](README_EN.md)

This bash script downloads website and database backup archives from an FTP server and manages old archives by deleting those that are too old while keeping a minimum number of recent backups.

## 🌟 Features

- 📥 Downloads website and database backup archives from an FTP server.
- 📝 Logs download activities and actions performed.
- 🗑️ Deletes old archives based on configurable criteria.
- 📂 Automatically creates backup directories if needed.

## 📋 Prerequisites

- `wget` must be installed on your machine.
- Access to an FTP server containing the website and database archives.

## 🛠️ Usage

1. Clone this repository or download the script.
2. Modify the variables at the top of the script to configure your FTP server details, backup paths, and archive deletion criteria.
3. Run the script.

## 🔧 Configurable Variables

- `USER`: FTP account username on the server.
- `PASSWORD`: FTP account password on the server.
- `SERVER`: FTP server address.
- `BACKUP_PATCH`: Path to the directory where backups will be stored.
- `LOGS_PATH`: Path to the directory where logs will be recorded.
- `DAYS_OLD`: Number of days after which archives are eligible for deletion (default: 60 days).
- `MIN_ARCHIVES`: Minimum number of archives to retain, even if they are older than the specified number of days (default: 4 archives).

## 📝 Script Example
```bash
#!/bin/bash

# Variables
USER="example@yourdomain.com"
PASSWORD="FTP_PASSWORD"
SERVER="ftp.example.com"
BACKUP_PATCH="/path/to/backup/folder"
DATE=$(date +"%Y-%m-%d")
LOGS_PATH="/path/to/logs"
DAYS_OLD=60   # Number of days old archives will be eligible for deletion
MIN_ARCHIVES=4 # Minimum number of archives to keep, even if older than $DAYS_OLD days

# Check if logs directory exists
if [ ! -d "$LOGS_PATH" ]; then
  echo "$(date '+%Y-%m-%d %H:%M:%S') - Logs directory $LOGS_PATH does not exist. Creating now"
  mkdir -p "$LOGS_PATH"
fi

# Log function
log() {
  local message=$1
  echo "$(date '+%Y-%m-%d %H:%M:%S') - $message" >>"$LOGS_PATH/${DATE}_script_backup_logs"
}

# Function to download site and its corresponding database archive
download_site_and_db() {
  local site=$1
  local db=${SITES_DBS[$site]}

  # Create backup directory for the site if it doesn't exist
  if [ ! -d "${BACKUP_PATH}/${site}" ]; then
    echo "$(date '+%Y-%m-%d %H:%M:%S') - Creating backup folder for site $site."
    mkdir -p "${BACKUP_PATH}/${site}"
  fi

  if [ -n "$site" ]; then
    log "[INFO] Downloading archive for site $site"
    wget ftp://${SERVER}/site_${site}* --ftp-user=${USER} --ftp-password=${PASSWORD} -P ${BACKUP_PATCH}/${site}
  else
    log "[ERROR] Failed to download archive for site $site."
  fi
  log "[SUCCESS] Download of archives for site $site completed"

  if [ -n "$db" ]; then
    log "[INFO] Downloading database archive $db"
    wget ftp://${SERVER}/db_${db}* --ftp-user=${USER} --ftp-password=${PASSWORD} -P ${BACKUP_PATCH}/${site}
  else
    log "[WARNING] No associated database found for site $site"
  fi

  log "[SUCCESS] Download of archives for site $site completed"
}

# Function to delete old archives older than $DAYS_OLD days while keeping the most recent $MIN_ARCHIVES
cleaning_archives_old() {
  log "[INFO] Deleting archives older than $DAYS_OLD days for site $site while keeping $MIN_ARCHIVES most recent"
  old_archives=$(find "${BACKUP_PATH}/${site}" -type f -mtime +$DAYS_OLD -print0 | sort -rz | tail -n +$((MIN_ARCHIVES + 1)))
  if [ -z "$old_archives" ]; then
    log "[INFO] No archives to delete for site $site"
  else
    log "[INFO] Archives to be deleted for site $site:"
    echo "$old_archives" | tr '\0' '\n' >>"$LOGS_PATH/${DATE}_script_backup_logs"
    echo "$old_archives" | xargs -0 rm -f
    if [ $? -eq 0 ]; then
      log "[SUCCESS] Deletion of old archives for site $site completed"
    else
      log "[ERROR] Failed to delete old archives for site $site"
    fi
  fi
}

# Define sites and their corresponding database backups
# On the left "example.com" is the name of the compressed archive containing the website files
# On the right "db_example" is the name of the compressed archive containing the database dump for the website
declare -A SITES_DBS=(
  ["example01.com"]="db_example01"
  ["example02.com"]="db_example02"
  ["example03.com"]="db_example03"
  ["example04.com"]="" # Example: Leave empty if the website does not have a database
  ["example05.com"]="db_example05"
  ["example06.com"]="db_example06"
)

# For each site:
# Downloads their archives and corresponding databases
# Deletes old archives older than $DAYS_OLD and keeps a retention of $MIN_ARCHIVES
for site in "${!SITES_DBS[@]}"; do
  log "========================================================================================"
  log "Starting processing for site $site"
  log "========================================================================================"
  download_site_and_db "$site"
  cleaning_archives_old "$site"
  log "========================================================================================"
  log "Finished processing for site $site."
  log "========================================================================================"
  log ""
done
```

## 📖 Function Explanations
### 📁 Log Directory Check and Creation
Checks if the logs directory exists and creates it if not.
```bash
if [ ! -d "$LOGS_PATH" ]; then
  echo "$(date '+%Y-%m-%d %H:%M:%S') - Logs directory $LOGS_PATH does not exist. Creating now"
  mkdir -p "$LOGS_PATH"
fi
```

### 📝 Log Function
Records a message with a timestamp in the log file.
```bash
log() {
  local message=$1
  echo "$(date '+%Y-%m-%d %H:%M:%S') - $message" >>"$LOGS_PATH/${DATE}_script_backup_logs"
}
```

### 📥 Download Function for Site and Database
Downloads the archives for the site and its corresponding database from the FTP server. Creates the backup directory for the site if it doesn't exist.
```bash
download_site_and_db() {
  local site=$1
  local db=${SITES_DBS[$site]}

  # Create backup directory for the site if it doesn't exist
  if [ ! -d "${BACKUP_PATH}/${site}" ]; then
    echo "$(date '+%Y-%m-%d %H:%M:%S') - Creating backup folder for site $site."
    mkdir -p "${BACKUP_PATH}/${site}"
  fi

  if [ -n "$site" ]; then
    log "[INFO] Downloading archive for site $site"
    wget ftp://${SERVER}/site_${site}* --ftp-user=${USER} --ftp-password=${PASSWORD} -P ${BACKUP_PATCH}/${site}
  else
    log "[ERROR] Failed to download archive for site $site."
  fi
  log "[SUCCESS] Download of archives for site $site completed"

  if [ -n "$db" ]; then
    log "[INFO] Downloading database archive $db"
    wget ftp://${SERVER}/db_${db}* --ftp-user=${USER} --ftp-password=${PASSWORD} -P ${BACKUP_PATCH}/${site}
  else
    log "[WARNING] No associated database found for site $site"
  fi

  log "[SUCCESS] Download of archives for site $site completed"
}
```
### 🧹 Function cleaning_archives_old
Deletes old archives older than `$DAYS_OLD` days for each site while keeping at least `$MIN_ARCHIVES` recent archives. Logs deleted archives.
```bash
cleaning_archives_old() {
  log "[INFO] Deleting archives older than $DAYS_OLD days for site $site while keeping $MIN_ARCHIVES most recent"
  old_archives=$(find "${BACKUP_PATH}/${site}" -type f -mtime +$DAYS_OLD -print0 | sort -rz | tail -n +$((MIN_ARCHIVES + 1)))
  if [ -z "$old_archives" ]; then
    log "[INFO] No archives to delete for site $site"
  else
    log "[INFO] Archives to be deleted for site $site:"
    echo "$old_archives" | tr '\0' '\n' >>"$LOGS_PATH/${DATE}_script_backup_logs"
    echo "$old_archives" | xargs -0 rm -f
    if [ $? -eq 0 ]; then
      log "[SUCCESS] Deletion of old archives for site $site completed"
    else
      log "[ERROR] Failed to delete old archives for site $site"
    fi
  fi
}
```

### 🔗 Association Table and Correspondence
Defines an associative array (dictionary) mapping each website to its database backup. If a website does not have a database, the value is left empty.
```bash
declare -A SITES_DBS=(
  ["example01.com"]="db_example01"
  ["example02.com"]="db_example02"
  ["example03.com"]="db_example03"
  ["example04.com"]="" # Example: Leave empty if the website does not have a database
  ["example05.com"]="db_example05"
  ["example06.com"]="db_example06"
)
```

### 🔄 Processing and Management of Backup Archives
Iterates through all sites defined in the associative array SITES_DBS, downloads their corresponding archives, and deletes old archives while keeping a minimum number of recent archives.
```bash
for site in "${!SITES_DBS[@]}"; do
  log "========================================================================================"
  log "Starting processing for site $site"
  log "========================================================================================"
  download_site_and_db "$site"
  cleaning_archives_old "$site"
  log "========================================================================================"
  log "Finished processing for site $site."
  log "========================================================================================"
  log ""
done
```

## 📜 License
This script is licensed under the **MIT License**.

## 🤝 Contribution
Contributions are welcome! Feel free to open an issue or submit a pull request.
