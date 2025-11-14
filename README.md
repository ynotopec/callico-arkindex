# Déploiement automatisé de Callico

Ce dépôt fournit un outillage "state of the art" pour déployer l'application [Callico](https://gitlab.teklia.com/callico/callico) de manière entièrement automatisée, avec exposition publique via HTTPS et une procédure de désinstallation propre.

## Aperçu

- **Installation automatisée** : script idempotent qui installe Docker, récupère le dépôt Callico, applique une configuration Traefik pour l'exposition HTTPS et prépare un service systemd pour assurer le démarrage automatique.
- **Exposition Internet** : Traefik sert de reverse-proxy et gère automatiquement les certificats TLS Let's Encrypt pour le domaine configuré.
- **Désinstallation simple** : script dédié qui arrête la pile, nettoie les ressources et retire le service systemd.

## Pré-requis

- Distribution Linux x86_64 (Debian/Ubuntu ou compatible) avec accès root.
- Ports **80** et **443** ouverts sur la machine pour l'émission de certificats TLS.
- Un enregistrement DNS pointant vers l'adresse IP publique de la machine.
- Docker Engine et le plugin `docker compose` installés. Si ce n'est pas le cas, installez-les en suivant la documentation officielle : <https://docs.docker.com/engine/install/>.

## Variables principales

| Variable | Description |
| --- | --- |
| `--domain` | Nom de domaine public utilisé pour exposer Callico. |
| `--letsencrypt-email` | Adresse e-mail pour l'enregistrement Let's Encrypt. |
| `--admin-username` | Nom d'utilisateur super administrateur Django créé automatiquement. |
| `--admin-email` | Adresse e-mail du super administrateur. |
| `--admin-password` | Mot de passe du super administrateur. Peut aussi être fourni via `--admin-password-file`. |
| `--target-dir` | Répertoire d'installation (défaut : `/opt/callico`). |

## Installation

```bash
sudo ./scripts/install.sh \
  --domain callico.example.com \
  --letsencrypt-email admin@example.com \
  --admin-username admin \
  --admin-email admin@example.com \
  --admin-password "MotDePasseSûr" \
  --target-dir /opt/callico
```

Le script va :

1. Arrêter proprement une installation existante lorsque `--force` est passé, puis cloner le dépôt Callico.
2. Générer un `docker-compose.override.yml` incluant Traefik et la configuration HTTPS.
3. Initialiser le répertoire `letsencrypt` et créer le fichier `acme.json` (permissions 600).
4. Démarrer la pile applicative via `docker compose`.
5. Lancer les migrations Django.
6. Créer un super utilisateur Django non interactif.
7. (Optionnel) Installer un service systemd `callico.service` pour assurer le démarrage automatique.

### Options supplémentaires

- `--force` : supprime le répertoire cible avant installation si celui-ci existe.
- `--skip-systemd` : n'installe pas le service systemd.
- `--git-url` : permet de spécifier une URL Git alternative pour Callico.
- `--admin-password-file` : lit le mot de passe admin depuis un fichier.

Après installation, Callico est accessible via `https://<domain>`.

## Désinstallation

```bash
sudo ./scripts/uninstall.sh --target-dir /opt/callico
```

Options disponibles :

- `--purge-volumes` : supprime également les volumes Docker associés (données persistées).
- `--skip-systemd` : ne tente pas de retirer le service systemd.

La désinstallation réalise :

1. Arrêt de la pile Docker (`docker compose down`).
2. Suppression éventuelle des volumes (si `--purge-volumes`).
3. Désactivation et suppression du service systemd créé lors de l'installation.
4. Suppression du répertoire cible.

## Architecture

```
/opt/callico
├── docker-compose.yml              # issu du dépôt Callico
├── docker-compose.override.yml     # généré par install.sh (Traefik + labels)
├── letsencrypt/
│   └── acme.json                   # stocke les certificats Let's Encrypt
└── ...                             # code et ressources Callico
```

Traefik écoute les ports 80/443 et redirige vers le service `callico` exposé sur le port interne `8000`. Les certificats sont renouvelés automatiquement.

## Sécurité

- Le mot de passe administrateur peut être fourni via fichier pour éviter de l'exposer dans l'historique shell.
- `acme.json` est créé avec la permission `600` pour protéger les clés privées.
- Les scripts sont idempotents : ils vérifient l'état avant d'appliquer les modifications, ce qui facilite leur utilisation dans des pipelines CI/CD.

## Tests locaux

Pour valider les scripts sans exécuter réellement de commandes sensibles, vous pouvez lancer `shellcheck` :

```bash
shellcheck scripts/*.sh
```

## Licence

Ce dépôt est publié sans licence explicite. Ajoutez la licence correspondant à votre usage avant diffusion.
