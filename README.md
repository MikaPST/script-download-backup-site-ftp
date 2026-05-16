# 💾 Website and Database Backup Script 📦

[🇬🇧 Read in English](README.md) | [🇫🇷 Lire en Français](README_FR.md)

This bash script generates backup archives of websites and their databases directly on the hosting server, and prepares them to be retrieved via FTP by the client script.

## 🌟 Features

- 🗄️ Database backup and compression via `mysqldump`.
- 📦 Website files archiving and compression via `tar`.
- 📝 Logging of backup operations and actions taken.
- 📂 Automatic creation of backup and log directories if needed.
- ✅ Success verification for each operation with error handling.

## 📋 Prerequisites

- `mysqldump` must be available on the server.
- `tar` and `gzip` must be installed on the server.
- Websites must be hosted under `/home/{USER}/{site_name}`.
- The MySQL user must have sufficient privileges to dump the databases.

## 🛠️ Usage

1. Clone this repository or download the script to your hosting server.
2. Edit the variables at the top of the script to match your environment.
3. Make the script executable: `chmod +x script_backup_server.sh`
4. Run it manually or schedule it via a cron job.

### ⏰ Cron Job Example

To run the script every day at 2:00 AM:

```bash
0 2 * * * /path/to/script_backup_server.sh
```

## 🔧 Variables to Configure

- `USER`: System username under which the websites are hosted.
- `DBADMIN`: Suffix of the MySQL username used for dumps (e.g. `DUMP` → user `USER_DUMP`).
- `DBPW`: Password of the MySQL user.
- `BACKUP_PATH`: Path to the directory where archives will be stored.
- `LOGS_PATH`: Path to the directory where logs will be saved.

## 📝 Script Example

```bash
#!/bin/bash

# Variables
USER="USER"
DBADMIN="DUMP"
DBPW="PASSWORD"
BACKUP_PATH="/PATH/TO/BACKUP"
LOGS_PATH="/PATH/TO/LOGS"
DATE=$(date +"%Y-%m-%d")

# Logging function (defined first)
log() {
    local message=$1
    echo "$(date +"%Y-%m-%d %H:%M:%S") - $message" >> "$LOGS_PATH/${DATE}_script_backup_logs"
}

# Check if the logs directory exists
if [ ! -d "$LOGS_PATH" ]; then
    echo "$(date +"%Y-%m-%d %H:%M:%S") - Logs directory $LOGS_PATH does not exist. Creating it..."
    mkdir -p "$LOGS_PATH"
fi

# Check if the backup directory exists
if [ ! -d "$BACKUP_PATH" ]; then
    log "Backup directory $BACKUP_PATH does not exist. Creating it..."
    mkdir -p "$BACKUP_PATH"
fi

# Function to back up a database
backup_database() {
    local db_name=$1
    local output_file="${BACKUP_PATH}/bdd_${db_name}_${DATE}.sql.gz"

    log "[INFO] Backing up and compressing database ${db_name}..."

    local tmp_file
    tmp_file=$(mktemp "${BACKUP_PATH}/bdd_${db_name}_${DATE}.XXXXXX.sql")

    mysqldump -u "${USER}_${DBADMIN}" -p"${DBPW}" "${USER}_${db_name}" > "$tmp_file"

    if [ $? -ne 0 ]; then
        log "[ERROR] mysqldump failed for database ${db_name}."
        rm -f "$tmp_file"
        return 1
    fi

    gzip -c "$tmp_file" > "$output_file"
    rm -f "$tmp_file"

    if [ ! -s "$output_file" ]; then
        log "[ERROR] Backup file for database ${db_name} is empty or missing."
        return 1
    fi

    log "[SUCCESS] Database ${db_name} backup complete: $(basename "$output_file")"
}

# Function to back up a website
backup_site() {
    local site_name=$1
    local output_file="${BACKUP_PATH}/site_${site_name}_${DATE}.tgz"
    local site_path="/home/${USER}/${site_name}"

    log "[INFO] Backing up and compressing site ${site_name}..."

    if [ ! -d "$site_path" ]; then
        log "[ERROR] Site directory for ${site_name} not found: $site_path"
        return 1
    fi

    tar -zcf "$output_file" -C "/home/${USER}" "${site_name}"

    if [ $? -ne 0 ]; then
        log "[ERROR] Compression failed for site ${site_name}."
        return 1
    fi

    if [ ! -s "$output_file" ]; then
        log "[ERROR] Backup file for site ${site_name} is empty or missing."
        return 1
    fi

    log "[SUCCESS] Site ${site_name} backup complete: $(basename "$output_file")"
}

# Define sites and their corresponding databases
declare -A SITES_DBS=(
    ["exemplesite01.com"]="db_site01"
    ["exemplesite02.com"]="db_site02"
    ["exemplesite03.com"]="db_site03"
    ["exemplesite04.com"]="" # Leave empty if the site has no database
    ["exemplesite05.com"]="db_site05"
    ["exemplesite06.com"]="db_site06"
)

# Loop through all sites, back up the DB then the site files
for site_name in "${!SITES_DBS[@]}"; do
    db_name=${SITES_DBS[$site_name]}

    log "========================================================================================"
    log "Starting processing for site $site_name"
    log "========================================================================================"

    if [ -n "$db_name" ]; then
        backup_database "$db_name"
    else
        log "[WARNING] No associated database found for site $site_name"
    fi

    backup_site "$site_name"

    log "========================================================================================"
    log "Processing complete for site $site_name"
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
    echo "$(date +"%Y-%m-%d %H:%M:%S") - $message" >> "$LOGS_PATH/${DATE}_script_backup_logs"
}
```

### 📁 Directory Check and Creation
Checks whether the log and backup directories exist, and creates them if necessary.

```bash
if [ ! -d "$LOGS_PATH" ]; then
    echo "$(date +"%Y-%m-%d %H:%M:%S") - Logs directory $LOGS_PATH does not exist. Creating it..."
    mkdir -p "$LOGS_PATH"
fi

if [ ! -d "$BACKUP_PATH" ]; then
    log "Backup directory $BACKUP_PATH does not exist. Creating it..."
    mkdir -p "$BACKUP_PATH"
fi
```

### 🗄️ backup_database Function
Dumps the database using `mysqldump`, compresses the output with `gzip`, and verifies each step. Uses a temporary file to catch `mysqldump` errors before compressing.

```bash
backup_database() {
    local db_name=$1
    local output_file="${BACKUP_PATH}/bdd_${db_name}_${DATE}.sql.gz"

    local tmp_file
    tmp_file=$(mktemp "${BACKUP_PATH}/bdd_${db_name}_${DATE}.XXXXXX.sql")

    mysqldump -u "${USER}_${DBADMIN}" -p"${DBPW}" "${USER}_${db_name}" > "$tmp_file"

    if [ $? -ne 0 ]; then
        log "[ERROR] mysqldump failed for database ${db_name}."
        rm -f "$tmp_file"
        return 1
    fi

    gzip -c "$tmp_file" > "$output_file"
    rm -f "$tmp_file"
    # ...
}
```

### 📦 backup_site Function
Archives and compresses the website files using `tar`. Checks that the site directory exists beforehand, then verifies the produced archive is not empty.

```bash
backup_site() {
    local site_name=$1
    local output_file="${BACKUP_PATH}/site_${site_name}_${DATE}.tgz"
    local site_path="/home/${USER}/${site_name}"

    if [ ! -d "$site_path" ]; then
        log "[ERROR] Site directory for ${site_name} not found: $site_path"
        return 1
    fi

    tar -zcf "$output_file" -C "/home/${USER}" "${site_name}"
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
    ["exemplesite04.com"]="" # Leave empty if the site has no database
    ["exemplesite05.com"]="db_site05"
    ["exemplesite06.com"]="db_site06"
)
```

### 🔄 Backup Processing Loop
Iterates over all sites defined in the `SITES_DBS` associative array, backs up the database if one exists, then archives the site files.

```bash
for site_name in "${!SITES_DBS[@]}"; do
    db_name=${SITES_DBS[$site_name]}

    log "========================================================================================"
    log "Starting processing for site $site_name"
    log "========================================================================================"

    if [ -n "$db_name" ]; then
        backup_database "$db_name"
    else
        log "[WARNING] No associated database found for site $site_name"
    fi

    backup_site "$site_name"

    log "========================================================================================"
    log "Processing complete for site $site_name"
    log "========================================================================================"
    log ""
done
```

## 🗂️ Archive Naming Convention

Generated archives follow this naming convention, compatible with the client script:

| Type | Format | Example |
|---|---|---|
| Database | `bdd_{db_name}_{YYYY-MM-DD}.sql.gz` | `bdd_db_site01_2025-01-15.sql.gz` |
| Website | `site_{site_name}_{YYYY-MM-DD}.tgz` | `site_exemplesite01.com_2025-01-15.tgz` |

## 🔗 Associated Client Script

This server-side script works in tandem with the **client script** available in this repository: [link to client script repository].

The client script is responsible for:
- Retrieving the archives produced by this script via FTP.
- Managing local archive retention (deletion of old backups).

## 📜 License
This script is licensed under the **MIT License**.

## 🤝 Contributing
Contributions are welcome! Feel free to open an issue or submit a pull request.
