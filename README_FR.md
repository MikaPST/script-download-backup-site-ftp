# 💾 Script de Téléchargement en FTP des Sauvegardes de Sites Web 📦

[🇬🇧 Read in English](README.md) | [🇫🇷 Lire en Français](README_FR.md)

Ce script bash télécharge les archives de sauvegarde des sites web et de leurs bases de données depuis un serveur FTP, et gère la rétention locale des archives en supprimant celles qui sont trop anciennes tout en conservant un nombre minimum de sauvegardes.

## 🌟 Fonctionnalités

- 📥 Téléchargement des archives des sites web et de leurs bases de données depuis un serveur FTP.
- 📝 Gestion des logs de téléchargement et des actions menées.
- 🗑️ Suppression des anciennes archives selon des critères configurables, basée sur la date contenue dans le nom du fichier.
- 🔒 Conservation garantie d'un nombre minimum d'archives, même si elles dépassent la limite de jours.
- 📂 Création automatique des répertoires de sauvegarde et de logs si nécessaire.
- ✅ Vérification du succès de chaque opération avec gestion des erreurs.

## 📋 Prérequis

- `wget` doit être installé sur votre machine.
- Accès à un serveur FTP contenant les archives des sites web et des bases de données.
- Les archives sur le serveur FTP doivent contenir une date au format `YYYY-MM-DD` dans leur nom de fichier.

## 🛠️ Utilisation

1. Clonez ce dépôt ou téléchargez le script.
2. Modifiez les variables en haut du script pour configurer les détails de votre serveur FTP, les chemins de sauvegarde et les critères de suppression des archives.
3. Rendez le script exécutable : `chmod +x script_backup_client.sh`
4. Exécutez le script manuellement ou planifiez-le via un cron job.

### ⏰ Exemple de Cron Job

Pour exécuter le script tous les jours à 3h du matin (après la génération des sauvegardes côté serveur) :

```bash
0 3 * * * /chemin/vers/script_backup_client.sh
```

## 🔧 Variables à Configurer

- `USER` : Nom d'utilisateur du compte FTP sur le serveur.
- `PASSWORD` : Mot de passe du compte FTP sur le serveur.
- `SERVER` : Adresse du serveur FTP.
- `BACKUP_PATH` : Chemin vers le répertoire où les sauvegardes seront stockées localement.
- `LOGS_PATH` : Chemin vers le répertoire où les logs seront enregistrés.
- `DAYS_OLD` : Nombre de jours après lesquels les archives seront candidates à la suppression (défaut : 60 jours).
- `MIN_ARCHIVES` : Nombre minimum d'archives à conserver par site, même si elles dépassent `DAYS_OLD` (défaut : 4 archives).

## 📝 Exemple de Script

```bash
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

# Fonction pour enregistrer les logs (définie en premier)
log() {
  local message=$1
  echo "$(date '+%Y-%m-%d %H:%M:%S') - $message" >>"$LOGS_PATH/${DATE}_script_backup_logs"
}

# Vérifier si le répertoire des logs existe
if [ ! -d "$LOGS_PATH" ]; then
  echo "$(date '+%Y-%m-%d %H:%M:%S') - Le répertoire des logs $LOGS_PATH n'existe pas. Création en cours"
  mkdir -p "$LOGS_PATH"
fi

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
# A gauche "exemplesite01.com" est le nom de l'archive compressée contenant les fichiers du site web
# A droite "db_site01" est le nom de l'archive compressée contenant le dump de la base de données
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
# Supprime les anciennes archives de plus de $DAYS_OLD jours en gardant $MIN_ARCHIVES archives minimum
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

### 📝 Fonction log
Définie en tout premier dans le script. Enregistre un message avec un horodatage dans le fichier de logs du jour.

```bash
log() {
  local message=$1
  echo "$(date '+%Y-%m-%d %H:%M:%S') - $message" >>"$LOGS_PATH/${DATE}_script_backup_logs"
}
```

### 📁 Vérification et Création des Répertoires
Vérifie si le répertoire des logs existe, et le crée si ce n'est pas le cas. Le répertoire de sauvegarde de chaque site est créé à la volée dans `download_site_and_db`.

```bash
if [ ! -d "$LOGS_PATH" ]; then
  echo "$(date '+%Y-%m-%d %H:%M:%S') - Le répertoire des logs $LOGS_PATH n'existe pas. Création en cours"
  mkdir -p "$LOGS_PATH"
fi
```

### 📥 Fonction download_site_and_db
Télécharge les archives du site et de sa base de données depuis le serveur FTP. Crée le répertoire de sauvegarde local si nécessaire, et vérifie le succès de chaque téléchargement.

```bash
download_site_and_db() {
  local site=$1
  local db=${SITES_DBS[$site]}

  if [ ! -d "${BACKUP_PATH}/${site}" ]; then
    log "[INFO] Création du dossier de sauvegarde du site $site."
    mkdir -p "${BACKUP_PATH}/${site}"
  fi

  wget ftp://${SERVER}/site_${site}* --ftp-user=${USER} --ftp-password=${PASSWORD} -P ${BACKUP_PATH}/${site}

  if [ $? -eq 0 ]; then
    log "[SUCCESS] Téléchargement de l'archive du site $site terminé"
  else
    log "[ERROR] Échec du téléchargement de l'archive du site $site."
  fi
  # ...
}
```

### 🧹 Fonction cleaning_archives_old
Supprime les anciennes archives pour chaque site en se basant sur la date `YYYY-MM-DD` contenue dans le nom du fichier. Conserve toujours au minimum `$MIN_ARCHIVES` archives récentes, et ne supprime que les fichiers dépassant `$DAYS_OLD` jours. Affiche un bilan dans les logs.

```bash
cleaning_archives_old() {
  local site=$1

  # Trier les archives du plus récent au plus ancien via la date dans leur nom
  mapfile -t all_archives < <(
    find "$backup_dir" -maxdepth 1 -type f \
    | grep -E '[0-9]{4}-[0-9]{2}-[0-9]{2}' \
    | sort -r
  )

  for i in "${!all_archives[@]}"; do
    # Conserver les MIN_ARCHIVES plus récentes quoi qu'il arrive
    if [ "$i" -lt "$MIN_ARCHIVES" ]; then continue; fi

    # Supprimer si plus vieux que DAYS_OLD jours
    if [ "$age_days" -gt "$DAYS_OLD" ]; then
      rm -f "$file"
    fi
  done
  # ...
}
```

### 🔗 Tableau d'Association et de Correspondance
Définit une table associative qui fait correspondre chaque site web à sa base de données. Si un site n'a pas de base de données, la valeur est laissée vide.

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
Parcourt tous les sites définis dans le tableau associatif `SITES_DBS`, télécharge leurs archives correspondantes, puis supprime les anciennes archives en garantissant une rétention minimum.

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

## 🗂️ Format des Archives Attendues

Ce script attend des archives dont le nom contient une date au format `YYYY-MM-DD`, compatible avec les archives produites par le script serveur associé :

| Type | Format attendu | Exemple |
|---|---|---|
| Base de données | `bdd_{db_name}_{YYYY-MM-DD}.sql.gz` | `bdd_db_site01_2025-01-15.sql.gz` |
| Site web | `site_{site_name}_{YYYY-MM-DD}.tgz` | `site_exemplesite01.com_2025-01-15.tgz` |

## 🔗 Script Serveur Associé

Ce script client fonctionne en tandem avec le **script serveur** disponible dans ce dépôt : [lien vers le dépôt du script serveur].

Le script serveur se charge de :
- Générer les dumps des bases de données via `mysqldump`.
- Archiver les fichiers des sites web via `tar`.
- Déposer les archives sur le serveur FTP pour que ce script puisse les récupérer.

## 📜 License
Ce script est sous licence **MIT License**.

## 🤝 Contribution
Les contributions sont les bienvenues ! N'hésitez pas à ouvrir une issue ou à soumettre une pull request.
