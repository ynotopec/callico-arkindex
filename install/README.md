# Installation de Callico (répertoire `install`)

Ce répertoire contient les scripts et fichiers nécessaires pour déployer une instance
Callico via Docker. La procédure ci-dessous décrit la première installation ainsi que
les principaux fichiers à connaître.

## Prérequis

- Docker
- Docker Compose v2 (`docker compose`)
- Accès à un terminal interactif pour répondre aux questions du script lors de la
  première exécution

## Étapes d'installation

1. Placez-vous dans le répertoire d'installation :

   ```bash
   cd install
   ```

2. Lancez le script d'installation :

   ```bash
   ./install.sh
   ```

   Lors de la première exécution, si le fichier d'environnement `production.env`
   n'existe pas, le script vous demandera :

   - le domaine racine à utiliser pour l'instance (par défaut `localhost`) ;
   - un mot de passe commun qui servira pour la base de données, l'utilisateur
     administrateur Django et Minio.

   Un aperçu du fichier `production.env` généré vous sera affiché avant écriture ;
   vous pourrez l'accepter ou recommencer en cas d'erreur. Le fichier est créé avec
   des valeurs cohérentes pour les sous-domaines (`tasks.`, `minio.`, `traefik.`) et
   les URL nécessaires. Si vous choisissez de ne pas l'enregistrer, un gabarit sera
   copié depuis `production.env.example` pour que vous puissiez le compléter
   manuellement.

3. Une fois le fichier `production.env` prêt, le script démarre l'ensemble des
   services Docker, applique les migrations et crée un super-utilisateur Django avec
   les informations contenues dans ce fichier.

## Personnalisation

- Le fichier `production.env` peut être modifié à tout moment pour ajuster les
  domaines, mots de passe ou services associés. Après modification, relancez
  `./install.sh` pour appliquer les changements.
- Pour une installation en production avec certificats TLS réels, renseignez une
  adresse e-mail valide pour `TRAEFIK_ACME_EMAIL` et des domaines publics.
- Les fichiers Traefik se trouvent dans `install/traefik/` et peuvent être adaptés à
  vos besoins.

## Désinstallation

Le script `uninstall.sh` permet d'arrêter et de supprimer les services Docker créés
par l'installation :

```bash
./uninstall.sh
```

Cela ne supprime pas automatiquement les volumes ou les sauvegardes associés. Pensez à
les retirer manuellement si nécessaire.
