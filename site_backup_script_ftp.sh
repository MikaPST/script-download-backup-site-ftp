#!/bin/bash

# Variables
USER="exemple@yourdomaine.com"
PASSWORD="FTP_PASSWORD"
SERVER="ftp.exemple.com"
BACKUP_PATH="/chemin/vers/dossier/backup"
DATE=$(date +"%Y-%m-%d")
LOGS_PATH="/chemin/vers/logs"
DAYS_OLD=60   # Nombre de jours d'ancienneté des archives avant suppression
MIN_ARCHIVES=4 # Nombre minimum d'archives à conserver

# Vérifier si le répertoire des logs existe
if [ ! -d "$LOGS_PATH" ]; then
  echo "$(date '+%Y-%m-%d %H:%M:%S') - Le répertoire des logs $LOGS_PATH n'existe pas. Création en cours"
  mkdir -p "$LOGS_PATH"
fi

# Fonction pour enregistrer les logs
log() {
  local message=$1
  echo "$(date '+%Y-%m-%d %H:%M:%S') - $message" >>"$LOGS_PATH/${DATE}_script_backup_logs"
}

# Fonction pour télécharger les archives pour un site et sa base de données correspondante
download_site_and_db() {
  local site=$1
  local db=${SITES_DBS[$site]}

  # Créer le répertoire de sauvegarde pour le site s'il n'existe pas
  if [ ! -d "${BACKUP_PATH}/${site}" ]; then
    log "[INFO] Création du dossier de sauvegarde du site $site."
    mkdir -p "${BACKUP_PATH}/${site}"
  fi

  if [ -n "$site" ]; then
    log "[INFO] Téléchargement de l'archive du site $site"
    wget ftp://${SERVER}/site_${site}* --ftp-user=${USER} --ftp-password=${PASSWORD} -P ${BACKUP_PATH}/${site}
    if [ $? -eq 0 ]; then
      log "[SUCCESS] Téléchargement de l'archive du site $site terminé"
    else
      log "[ERROR] Échec du téléchargement de l'archive du site $site."
    fi
  fi

  if [ -n "$db" ]; then
    log "[INFO] Téléchargement de l'archive de la base de données $db"
    wget ftp://${SERVER}/bdd_${db}* --ftp-user=${USER} --ftp-password=${PASSWORD} -P ${BACKUP_PATH}/${site}
    if [ $? -eq 0 ]; then
      log "[SUCCESS] Téléchargement de l'archive de la base de données $db terminé"
    else
      log "[ERROR] Échec du téléchargement de l'archive de la base de données $db."
    fi
  else
    log "[WARNING] Aucune base de données associée trouvée pour le site $site"
  fi
}

# Fonction pour supprimer les anciennes archives en se basant sur la date dans le nom du fichier
cleaning_archives_old() {
  local site=$1
  log "[INFO] Suppression des archives de plus de $DAYS_OLD jours pour $site (rétention min : $MIN_ARCHIVES)"

  local backup_dir="${BACKUP_PATH}/${site}"

  # Extraire les fichiers contenant une date YYYY-MM-DD dans leur nom, triés du plus récent au plus ancien
  local all_archives
  mapfile -t all_archives < <(
    find "$backup_dir" -maxdepth 1 -type f \
    | grep -E '[0-9]{4}-[0-9]{2}-[0-9]{2}' \
    | sort -r
  )

  local total=${#all_archives[@]}
  log "[INFO] $total archive(s) trouvée(s) pour $site"

  if [ "$total" -eq 0 ]; then
    log "[INFO] Aucune archive trouvée pour $site"
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

    # Extraire la date YYYY-MM-DD du nom du fichier
    local file_date
    file_date=$(echo "$filename" | grep -oE '[0-9]{4}-[0-9]{2}-[0-9]{2}' | head -1)

    if [ -z "$file_date" ]; then
      log "[WARNING] Impossible d'extraire la date de : $filename — ignoré"
      continue
    fi

    # Calculer l'âge du fichier en jours
    local file_epoch
    file_epoch=$(date -d "$file_date" +%s 2>/dev/null)

    if [ -z "$file_epoch" ]; then
      log "[WARNING] Date invalide '$file_date' dans : $filename — ignoré"
      continue
    fi

    local age_days=$(( (today - file_epoch) / 86400 ))

    # Conserver si dans le top $MIN_ARCHIVES (index 0 à MIN_ARCHIVES-1)
    if [ "$i" -lt "$MIN_ARCHIVES" ]; then
      log "[INFO] Conservé (top $MIN_ARCHIVES) : $filename ($age_days j)"
      (( skipped++ ))
      continue
    fi

    # Supprimer si plus vieux que $DAYS_OLD jours
    if [ "$age_days" -gt "$DAYS_OLD" ]; then
      log "[INFO] Suppression : $filename ($age_days j > $DAYS_OLD j)"
      if rm -f "$file"; then
        log "[SUCCESS] Supprimé : $filename"
        (( deleted++ ))
      else
        log "[ERROR] Échec suppression : $filename"
      fi
    else
      log "[INFO] Conservé (récent) : $filename ($age_days j)"
      (( skipped++ ))
    fi
  done

  log "[INFO] Bilan $site — Supprimés : $deleted | Conservés : $skipped"
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

# Pour chaque site :
# Télécharge les archives et les bases de données correspondantes
# Supprime les anciennes archives plus de $DAYS_OLD et garde une rétention de $MIN_ARCHIVES
for site in "${!SITES_DBS[@]}"; do
  log "========================================================================================"
  log "Début du traitement pour le site $site"
  log "========================================================================================"
  download_site_and_db "$site"
  cleaning_archives_old "$site"
  log "========================================================================================"
  log "Fin du traitement pour le site $site."
  log "========================================================================================"
  log ""
done
