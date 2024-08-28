#!/bin/bash
set -e

# Vérifier si l'utilisateur admin existe
echo "Vérification de l'existence de l'utilisateur admin..."
USER_EXISTS=$(mysql -u root -sse "SELECT COUNT(*) FROM observium.users WHERE username='admin';")

if [ "$USER_EXISTS" -eq 0 ]; then
    echo "L'utilisateur admin n'existe pas. Création en cours..."
    cd /opt/observium
    php adduser.php admin adminpassword 10
    echo "Utilisateur admin créé avec succès."
else
    echo "L'utilisateur admin existe déjà."
fi

# Démarrer Apache
echo "redémarrage d'Apache..."
service apache2 restart

# Exécuter la commande passée en argument (par défaut : bash)
exec "$@"
