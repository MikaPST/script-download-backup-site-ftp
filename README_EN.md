# 💾 FTP Download Script for Website Backup Archives 📦

[🇫🇷 Lire en Français](README.md) | [🇬🇧 Read in English](README_EN.md)

This bash script downloads backup archives of websites and their databases from an FTP server, and manages old archives by deleting those that are too old while retaining a minimum number of archives.

## 🌟 Features

- 📥 Download website and database archives from an FTP server.
- 📝 Manage download logs and actions taken.
- 🗑️ Delete old archives based on configurable criteria.

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
- `MIN_ARCHIVES`: Minimum number of archives to retain, even if they are older than the specified number of days (default: 3 archives).

## 📝 Script Example

```bash
#!/bin/bash

# Variables
USER="example@yourdomain.com"
PASSWORD="FTP_PASSWORD"
SERVER="ftp.example.com"
BACKUP_PATCH="/path/to/backup/directory"
DATE=$(date +"%Y-%m-%d")
LOGS_PATH="/path/to/logs"
DAYS_OLD=60   # Number of days after which archives are eligible for deletion
MIN_ARCHIVES=3 # Minimum number of archives to retain

# Check if the log directory exists
if [ ! -d "$LOGS_PATH" ]; then
    echo "$(date '+%Y-%m-%d %H:%M:%S') - The log directory $LOGS_PATH does not exist. Creating..."
    mkdir -p "$LOGS_PATH"
fi

# Function to record logs
log() {
    local message=$1
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $message" >> "$LOGS_PATH/${DATE}_script_backup_logs"
}

# Function to download archives for a site and its corresponding database
download_site_and_db() {
  local site=$1
  local db=${SITES_DBS[$site]}

  log "Downloading archive for site $site"
  wget ftp://${SERVER}/site_${site}* --ftp-user=${USER} --ftp-password=${PASSWORD} -P ${BACKUP_PATCH}/${site}

  if [ -n "$db" ]; then
    log "Downloading archive for database $db"
    wget ftp://${SERVER}/db_${db}* --ftp-user=${USER} --ftp-password=${PASSWORD} -P ${BACKUP_PATCH}/${site}
  else
    log "No associated database found for site $site"
  fi

  log "Download of archives for site $site completed"
}

# Define sites and their corresponding databases
# On the left "examplesite01.com" is the name of the compressed archive containing the website files
# On the right "db_site01" is the name of the compressed archive containing the database dump of the website
declare -A SITES_DBS=(
  ["examplesite01.com"]="db_site01"
  ["examplesite02.com"]="db_site02"
  ["examplesite03.com"]="db_site03"
  ["examplesite04.com"]="" # Example: Leave empty if the website does not have a database
  ["examplesite05.com"]="db_site05"
  ["examplesite06.com"]="db_site06"
)

# Iterate over all sites and download their corresponding archives
for site in "${!SITES_DBS[@]}"; do
  download_site_and_db "$site"
  
  # Delete old archives older than $DAYS_OLD days while retaining the $MIN_ARCHIVES most recent ones
  find "${BACKUP_PATCH}/${site}" -type f -mtime +$DAYS_OLD -print0 | sort -rz | tail -n +$((MIN_ARCHIVES+1)) | xargs -0 rm -f
done
```

## 📖 Function Explanations
### 📁 Log Directory Check and Creation

```bash
if [ ! -d "$LOGS_PATH" ]; then
    echo "$(date '+%Y-%m-%d %H:%M:%S') - The log directory $LOGS_PATH does not exist. Creating..."
    mkdir -p "$LOGS_PATH"
fi
```
Checks if the log directory exists and creates it if it doesn't.

### 📝 Log Function
```bash
log() {
    local message=$1
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $message" >> "$LOGS_PATH/${DATE}_script_backup_logs"
}
```
Records a message with a timestamp in the log file.

### 📥 Download Function for Site and Database
```bash
download_site_and_db() {
  local site=$1
  local db=${SITES_DBS[$site]}

  log "Downloading archive for site $site"
  wget ftp://${SERVER}/site_${site}* --ftp-user=${USER} --ftp-password=${PASSWORD} -P ${BACKUP_PATCH}/${site}

  if [ -n "$db" ]; then
    log "Downloading archive for database $db"
    wget ftp://${SERVER}/db_${db}* --ftp-user=${USER} --ftp-password=${PASSWORD} -P ${BACKUP_PATCH}/${site}
  else
    log "No associated database found for site $site"
  fi

  log "Download of archives for site $site completed"
}
```
Downloads the website and its corresponding database archives from the FTP server and logs the operations.

### 🔗 Association Table and Correspondence

```bash
declare -A SITES_DBS=(
  ["examplesite01.com"]="db_site01"
  ["examplesite02.com"]="db_site02"
  ["examplesite03.com"]="db_site03"
  ["examplesite04.com"]="" # Example: Leave empty if the website does not have a database
  ["examplesite05.com"]="db_site05"
  ["examplesite06.com"]="db_site06"
)
```
Defines an associative array (dictionary) that maps each website to its database. If a website does not have a database, the value is left empty.

### 🔄 Iterate and Delete Old Archives with Restriction
```bash
for site in "${!SITES_DBS[@]}"; do
  download_site_and_db "$site"
  
  # Delete old archives older than $DAYS_OLD days while retaining the $MIN_ARCHIVES most recent ones
  find "${BACKUP_PATCH}/${site}" -type f -mtime +$DAYS_OLD -print0 | sort -rz | tail -n +$((MIN_ARCHIVES+1)) | xargs -0 rm -f
done
```
Iterates over all sites defined in the associative array SITES_DBS, downloads their corresponding archives, and deletes old archives while keeping a minimum number of recent backups.

## 📜 License
This script is licensed under the **MIT License**.

## 🤝 Contribution
Contributions are welcome! Feel free to open an issue or submit a pull request.
