# 💾 Script de Téléchargement en FTP des Sauvegardes de Sites Web 📦

[🇫🇷 Lire en Français](README.md) | [🇬🇧 Read in English](README_EN.md)

Ce script bash télécharge les archives de sauvegarde des sites web et de leurs bases de données depuis un serveur en FTP, et gère les anciennes archives en supprimant celles qui sont trop anciennes tout en conservant un nombre minimum d'archives.

## 🌟 Fonctionnalités

- 📥 Téléchargement des archives des sites web et de leurs bases de données depuis un serveur en FTP.
- 📝 Gestion des logs de téléchargement et des actions menées.
- 🗑️ Suppression des anciennes archives selon des critères configurables.
- 📂 Création automatique des répertoires de sauvegarde si nécessaire.

## 📋 Prérequis

- `wget` doit être installé sur votre machine.
- Accès à un serveur FTP contenant les archives des sites web et des bases de données.

## 🛠️ Utilisation

1. Clonez ce dépôt ou téléchargez le script.
2. Modifiez les variables en haut du script pour configurer les détails de votre serveur FTP, les chemins de sauvegarde et les critères de suppression des archives.
3. Exécutez le script.

## 🔧 Variables à Configurer

- `USER`: Nom d'utilisateur du compte FTP sur le serveur.
- `PASSWORD`: Mot de passe du compte FTP sur le serveur.
- `SERVER`: Adresse du serveur FTP.
- `BACKUP_PATCH`: Chemin vers le répertoire où les sauvegardes seront stockées.
- `LOGS_PATH`: Chemin vers le répertoire où les logs seront enregistrés.
- `DAYS_OLD`: Nombre de jours après lesquels les archives seront candidates à la suppression (défaut: 60 jours).
- `MIN_ARCHIVES`: Nombre minimum d'archives à conserver, même si elles sont plus anciennes que le nombre de jours spécifié (défaut: 4 archives).

## 📝 Exemple de Script

```bash
#!/bin/bash

# Variables
USER="exemple@yourdomaine.com"
PASSWORD="FTP_PASSWORD"
SERVER="ftp.exemple.com"
BACKUP_PATCH="/chemin/vers/dossier/backup"
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
    echo "$(date '+%Y-%m-%d %H:%M:%S') - Création du dossier de sauvegarde du site $site."
    mkdir -p "${BACKUP_PATH}/${site}"
  fi

  if [ -n "$site" ]; then
    log "[INFO] Téléchargement de l'archive du site $site"
    wget ftp://${SERVER}/site_${site}* --ftp-user=${USER} --ftp-password=${PASSWORD} -P ${BACKUP_PATCH}/${site}
  else
    log "[ERROR] Échec du téléchargement de l'archive du site $site."
  fi
  log "[SUCCESS] Téléchargement des archives pour le site $site terminé"

  if [ -n "$db" ]; then
    log "[INFO] Téléchargement de l'archive de la base de données $db"
    wget ftp://${SERVER}/bdd_${db}* --ftp-user=${USER} --ftp-password=${PASSWORD} -P ${BACKUP_PATCH}/${site}
  else
    log "[WARNING] Aucune base de données associée trouvée pour le site $site"
  fi

  log "[SUCCESS] Téléchargement des archives pour le site $site terminé"
}

# Fonction pour supprimer les anciennes archives de plus de $DAYS_OLD jours en conservant les $MIN_ARCHIVES plus récentes
cleaning_archives_old() {
  log "[INFO] Suppression des anciennes archives de plus de $DAYS_OLD jours pour le site $site en conservant les $MIN_ARCHIVES plus récentes"
  old_archives=$(find "${BACKUP_PATH}/${site}" -type f -mtime +$DAYS_OLD -print0 | sort -rz | tail -n +$((MIN_ARCHIVES + 1)))
  if [ -z "$old_archives" ]; then
    log "[INFO] Aucune archive à supprimer pour le site $site"
  else
    log "[INFO] Archives à supprimer pour le site $site:"
    echo "$old_archives" | tr '\0' '\n' >>"$LOGS_PATH/${DATE}_script_backup_logs"
    echo "$old_archives" | xargs -0 rm -f
    if [ $? -eq 0 ]; then
      log "[SUCCESS] Suppression des anciennes archives terminée pour le site $site"
    else
      log "[ERROR] Échec de la suppression des anciennes archives pour le site $site"
    fi
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
```

## 📖 Explications des Fonctions
### 📁 Vérification et Création du Répertoire de Logs
Vérifie si le répertoire des logs existe, et le crée si ce n'est pas le cas.

```bash
if [ ! -d "$LOGS_PATH" ]; then
    echo "$(date '+%Y-%m-%d %H:%M:%S') - Le répertoire des logs $LOGS_PATH n'existe pas. Création en cours..."
    mkdir -p "$LOGS_PATH"
fi
```

### 📝 Fonction log
Enregistre un message avec un horodatage dans le fichier de logs.
```bash
log() {
    local message=$1
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $message" >> "$LOGS_PATH/${DATE}_script_backup_logs"
}
```


### 📥 Fonction download_site_and_db
Télécharge les archives du site et de sa base de données correspondante depuis le serveur FTP. Crée le répertoire de sauvegarde pour le site s'il n'existe pas encore.
```bash
download_site_and_db() {
  local site=$1
  local db=${SITES_DBS[$site]}

  # Créer le répertoire de sauvegarde pour le site s'il n'existe pas
  if [ ! -d "${BACKUP_PATH}/${site}" ]; then
    echo "$(date '+%Y-%m-%d %H:%M:%S') - Création du dossier de sauvegarde du site $site."
    mkdir -p "${BACKUP_PATH}/${site}"
  fi

  if [ -n "$site" ]; then
    log "[INFO] Téléchargement de l'archive du site $site"
    wget ftp://${SERVER}/site_${site}* --ftp-user=${USER} --ftp-password=${PASSWORD} -P ${BACKUP_PATCH}/${site}
  else
    log "[ERROR] Échec du téléchargement de l'archive du site $site."
  fi
  log "[SUCCESS] Téléchargement des archives pour le site $site terminé"

  if [ -n "$db" ]; then
    log "[INFO] Téléchargement de l'archive de la base de données $db"
    wget ftp://${SERVER}/bdd_${db}* --ftp-user=${USER} --ftp-password=${PASSWORD} -P ${BACKUP_PATCH}/${site}
  else
    log "[WARNING] Aucune base de données associée trouvée pour le site $site"
  fi

  log "[SUCCESS] Téléchargement des archives pour le site $site terminé"
}
```
### 🧹 Fonction cleaning_archives_old
Supprime les anciennes archives de plus de $DAYS_OLD jours pour chaque site en conservant au moins $MIN_ARCHIVES archives récentes. Enregistre les archives supprimées dans le fichier de logs.
```bash
cleaning_archives_old() {
  log "[INFO] Suppression des anciennes archives de plus de $DAYS_OLD jours pour le site $site en conservant les $MIN_ARCHIVES plus récentes"
  old_archives=$(find "${BACKUP_PATH}/${site}" -type f -mtime +$DAYS_OLD -print0 | sort -rz | tail -n +$((MIN_ARCHIVES + 1)))
  if [ -z "$old_archives" ]; then
    log "[INFO] Aucune archive à supprimer pour le site $site"
  else
    log "[INFO] Archives à supprimer pour le site $site:"
    echo "$old_archives" | tr '\0' '\n' >>"$LOGS_PATH/${DATE}_script_backup_logs"
    echo "$old_archives" | xargs -0 rm -f
    if [ $? -eq 0 ]; then
      log "[SUCCESS] Suppression des anciennes archives terminée pour le site $site"
    else
      log "[ERROR] Échec de la suppression des anciennes archives pour le site $site"
    fi
  fi
}
```

### 🔗 Tableau d'Association et de Correspondance
Cette fonction définit une table associative (dictionnaire) qui fait correspondre chaque site web à sa base de données. Si un site web n'a pas de base de données, la valeur est laissée vide.
```bash
declare -A SITES_DBS=(
  ["exemplesite01.com"]="db_site01"
  ["exemplesite02.com"]="db_site02"
  ["exemplesite03.com"]="db_site03"
  ["exemplesite04.com"]="" # Exemple : Laisser vide si le site Web n'a pas de base de données
  ["exemplesite05.com"]="db_site05"
  ["exemplesite06.com"]="db_site06"
)
```

### 🔄 Traitement et Gestion des Archives de Sauvegarde
Parcourt tous les sites définis dans le tableau associatif SITES_DBS, télécharge leurs archives correspondantes, et supprime les anciennes archives en gardant un nombre minimum d'archives.
```bash
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
```

## 📜 License
Ce script est sous licence **MIT License**.

## 🤝 Contribution
Les contributions sont les bienvenues! N'hésitez pas à ouvrir une issue ou à soumettre une pull request.
