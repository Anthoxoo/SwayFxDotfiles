cat << 'EOF' > ~/clone_repos.sh
#!/usr/bin/env bash

USER="Anthoxoo"
DEST_DIR="$HOME/Development"

mkdir -p "$DEST_DIR"
cd "$DEST_DIR" || exit 1

echo "Récupération des dépôts publics de $USER..."

# Récupère la liste des URLs HTTPS (remplace "clone_url" par "ssh_url" si tu préfères cloner en SSH)
REPOS=$(curl -s "https://api.github.com/users/$USER/repos?per_page=100" | grep -o '"clone_url": "[^"]*' | cut -d'"' -f4)

for url in $REPOS; do
    repo_name=$(basename "$url" .git)
    if [ -d "$repo_name" ]; then
        echo "↻ [$repo_name] déjà présent — mise à jour..."
        git -C "$repo_name" pull --ff-only
    else
        echo "↓ Clonage de [$repo_name]..."
        git clone "$url"
    fi
done

echo "Terminé ! Tous les dépôts sont dans $DEST_DIR."
EOF

chmod +x ~/clone_repos.sh
~/clone_repos.sh
