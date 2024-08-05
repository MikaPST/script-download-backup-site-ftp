#!/bin/bash

# Variables
USER="exemple@yourdomaine.com"
PASSWORD="FTP_PASSWORD"
SERVER="ftp.exemple.com"
BACKUP_PATCH="/chemin/vers/dossier/backup"
DATE=$(date +"%Y-%m-%d")
LOGS_PATH="/chemin/vers/logs"
DAYS_OLD=60   # Nombre de jours d'ancienneté des archives avant suppression
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
    local site_archive_found=false
    local db_archive_found=false

    log "Début du téléchargement pour le site $site"
    wget -q --spider ftp://${SERVER}/site_${site}* --ftp-user=${USER} --ftp-password=${PASSWORD}
    if [ $? -ne 0 ]; then
        log "Erreur: L'archive du site $site n'a pas été trouvée ou n'a pas pu être téléchargée"
    else
        wget ftp://${SERVER}/site_${site}* --ftp-user=${USER} --ftp-password=${PASSWORD} -P ${BACKUP_PATCH}/${site}
        log "Téléchargement de l'archive du site $site terminé"
        site_archive_found=true
    fi

    if [ -n "$db" ]; then
        wget -q --spider ftp://${SERVER}/bdd_${db}* --ftp-user=${USER} --ftp-password=${PASSWORD}
        if [ $? -ne 0 ]; then
            log "Erreur: L'archive de la base de données $db n'a pas été trouvée ou n'a pas pu être téléchargée"
        else
            wget ftp://${SERVER}/bdd_${db}* --ftp-user=${USER} --ftp-password=${PASSWORD} -P ${BACKUP_PATCH}/${site}
            log "Téléchargement de l'archive de la base de données $db terminé"
            db_archive_found=true
        fi
    else
        log "Aucune base de données associée trouvée pour le site $site"
    fi

    if $site_archive_found || $db_archive_found; then
        log "Téléchargement des archives pour le site $site terminé"
    else
        log "Téléchargement des archives pour le site $site partiellement ou entièrement échoué"
    fi
}

# Définition des sites et de leurs bases de données correspondantes
# A gauche "exemplesite01.com" est le nom de l'archive compressé contenant les fichiers du site web
# A droite "db_site01" est le nom de l'archive compressée contenant le dump de la base de données du site web
declare -A SITES_DBS=(
  ["exemplesite01.com"]="db_site01"
  ["exemplesite02.com"]="db_site02"
  ["exemplesite03.com"]="db_site03"
  ["exemplesite04.com"]="" # Exemple : Laisser vide si le site Web n'a pas de base de données
  ["exemplesite05.com"]="db_site05"
  ["exemplesite06.com"]="db_site06"
)

# Parcourir tous les sites et télécharger leurs archives correspondantes
for site in "${!SITES_DBS[@]}"; do
    log "============================="
    log "Début du traitement pour le site $site"
    log "============================="

    download_site_and_db "$site"
    
    log "Suppression des anciennes archives de plus de $DAYS_OLD jours pour le site $site en conservant les $MIN_ARCHIVES plus récentes"
    old_archives=$(find "${BACKUP_PATCH}/${site}" -type f -mtime +$DAYS_OLD -print0 | sort -rz | tail -n +$((MIN_ARCHIVES+1)))
    if [ -z "$old_archives" ]; then
        log "Aucune archive à supprimer pour le site $site"
    else
        log "Archives à supprimer pour le site $site:"
        echo "$old_archives" | tr '\0' '\n' >> "$LOGS_PATH/${DATE}_script_backup_logs"
        echo "$old_archives" | xargs -0 rm -f
        log "Suppression des anciennes archives terminée pour le site $site"
    fi

    log "============================="
    log "Fin du traitement pour le site $site"
    log "============================="
done
