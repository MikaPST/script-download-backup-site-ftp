#!/bin/bash

# Variables
USER="exemple@yourdomaine.com"
PASSWORD="FTP_PASSWORD"
SERVER="ftp.exemple.com"
BACKUP_PATCH="/chemin/vers/dossier/backup"
DATE=$(date +"%Y-%m-%d")
LOGS_PATH="/chemin/vers/logs"
DAYS_OLD=30   # Nombre de jours d'ancienneté des archives avant suppression
MIN_ARCHIVES=3 # Nombre minimum d'archives à conserver

# Vérifier si le répertoire des logs existe
if [ ! -d "$LOGS_PATH" ]; then
    echo "$(date '+%Y-%m-%d %H:%M:%S') - Le répertoire des logs $LOGS_PATH n'existe pas. Création en cours..."
    mkdir -p "$LOGS_PATH"
fi

# Fonction pour enregistrer les logs
log() {
    local message=$1
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $message" >> "$LOGS_PATH/${DATE}_script_backup_logs"
}

# Fonction pour télécharger les archives pour un site et sa base de données correspondante
download_site_and_db() {
  local site=$1
  local db=${SITES_DBS[$site]}

  log "Téléchargement de l'archive du site $site"
  wget ftp://${SERVER}/site_${site}* --ftp-user=${USER} --ftp-password=${PASSWORD} -P ${BACKUP_PATCH}/${site}

  if [ -n "$db" ]; then
    log "Téléchargement de l'archive de la base de données $db"
    wget ftp://${SERVER}/bdd_${db}* --ftp-user=${USER} --ftp-password=${PASSWORD} -P ${BACKUP_PATCH}/${site}
  else
    log "Aucune base de données associée trouvée pour le site $site"
  fi

  log "Téléchargement des archives pour le site $site terminé"
}

# Définition des sites et de leurs bases de données correspondantes
declare -A SITES_DBS=(
  ["exemplesite01.com"]="db_site01"
  ["exemplesite02.com"]="db_site02"
  ["exemplesite03.com"]="db_site03"
  ["exemplesite04.com"]="db_site04"
  ["exemplesite05.com"]="db_site05"
  ["exemplesite06.com"]="db_site06"
)

# Parcourir tous les sites et télécharger leurs archives correspondantes
for site in "${!SITES_DBS[@]}"; do
  download_site_and_db "$site"
  
  # Supprimer les anciennes archives de plus de $DAYS_OLD jours en conservant les $MIN_ARCHIVES plus récentes
  find "${BACKUP_PATCH}/${site}" -type f -mtime +$DAYS_OLD -print0 | sort -rz | tail -n +$((MIN_ARCHIVES+1)) | xargs -0 rm -f
done
