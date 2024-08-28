# Utiliser l'image de base Debian
FROM debian:12
MAINTAINER  Edouard Bessou

# Mettre à jour le système et installer les dépendances nécessaires
RUN apt-get update && apt-get install -y \
    wget \
    libapache2-mod-php8.2 \
    php8.2-cli \
    php8.2-mysql \
    php8.2-gd \
    php8.2-bcmath \
    php8.2-mbstring \
    php8.2-opcache \
    php8.2-apcu \
    php8.2-curl \
    php-json \
    php-pear \
    snmp \
    fping \
    mariadb-server \
    mariadb-client \
    python3-mysqldb \
    python-is-python3 \
    python3-pymysql \
    rrdtool \
    subversion \
    whois \
    mtr-tiny \
    ipmitool \
    graphviz \
    imagemagick \
    apache2 \
    libvirt-clients \
    rancid \
    cron \
    && apt-get clean

# Configurer le ServerName dans Apache pour éviter les avertissements
RUN echo "ServerName localhost" >> /etc/apache2/apache2.conf

# Télécharger et installer Observium
RUN mkdir -p /.OBSERVIUM/Production/observium && cd /.OBSERVIUM/Production \
    && wget http://www.observium.org/observium-community-latest.tar.gz \
    && tar zxvf observium-community-latest.tar.gz \
    && mv observium-community-* observium

# Créer les répertoires requis par Observium
RUN cd /.OBSERVIUM/Production/observium \
    && mkdir logs rrd \
    && chown www-data:www-data rrd logs

# Configurer Apache pour servir Observium
RUN echo '<VirtualHost *:80>\n\
    ServerAdmin webmaster@localhost\n\
    DocumentRoot /.OBSERVIUM/Production/observium/html\n\
    <Directory />\n\
        Options FollowSymLinks\n\
        AllowOverride None\n\
    </Directory>\n\
    <Directory /.OBSERVIUM/Production/observium/html/>\n\
        DirectoryIndex index.php\n\
        Options Indexes FollowSymLinks MultiViews\n\
        AllowOverride All\n\
        Require all granted\n\
    </Directory>\n\
    ErrorLog ${APACHE_LOG_DIR}/error.log\n\
    CustomLog ${APACHE_LOG_DIR}/access.log combined\n\
</VirtualHost>' > /etc/apache2/sites-available/observium.conf \
    && a2dissite 000-default.conf \
    && a2ensite observium.conf \
    && a2enmod rewrite \
    && a2dismod mpm_event \
    && a2enmod mpm_prefork \
    && apache2ctl restart

# Configurer la base de données MariaDB et initialiser le schéma d'Observium
RUN service mariadb start \
    && mysql -u root -e "CREATE DATABASE observium DEFAULT CHARACTER SET utf8 COLLATE utf8_general_ci;" \
    && mysql -u root -e "CREATE USER 'observium'@'localhost' IDENTIFIED BY 'observiumpassword';" \
    && mysql -u root -e "GRANT ALL PRIVILEGES ON observium.* TO 'observium'@'localhost';" \
    && mysql -u root -e "FLUSH PRIVILEGES;" \
    && cd /.OBSERVIUM/Production/observium \
    && cp config.php.default config.php \
    && sed -i "s/'USERNAME'/'observium'/g" config.php \
    && sed -i "s/'PASSWORD'/'observiumpassword'/g" config.php \
    && php discovery.php -u

# Créer un compte administrateur Observium et ajouter un appareil de surveillance
RUN cd /.OBSERVIUM/Production/observium \
    && php adduser.php admin adminpassword 10 \
    && php add_device.php localhost public v2c \
    && php discovery.php -h all \
    && php poller.php -h all

# Installer et configurer RANCID
RUN useradd -m -s /bin/bash rancid \
    && mkdir -p /var/lib/rancid/SVN \
    && chown -R rancid:rancid /var/lib/rancid \
    && echo "LIST_OF_GROUPS=\"observium\"" > /etc/rancid/rancid.conf \
    && sed -i 's#^CVSROOT=.*#CVSROOT=$BASEDIR/SVN; export CVSROOT#' /etc/rancid/rancid.conf \
    && sed -i 's/^RCSSYS=.*/RCSSYS=svn; export RCSSYS/' /etc/rancid/rancid.conf \
    && su - rancid -c "/var/lib/rancid/bin/rancid-cvs" \
    && echo "add user * rancid\nadd password * password\nadd identity * /var/lib/rancid/.ssh/id_dsa\nadd method * ssh\nadd noenable * {1}" > /var/lib/rancid/.cloginrc \
    && chown -R rancid:rancid /var/lib/rancid/.cloginrc \
    && usermod -a -G rancid www-data

# Intégrer RANCID à Observium
RUN echo "\$config['rancid_configs'][] = \"/var/lib/rancid/observium/configs/\";" >> /.OBSERVIUM/Production/observium/config.php \
    && echo "\$config['rancid_ignorecomments'] = 0;" >> /.OBSERVIUM/Production/observium/config.php \
    && echo "\$config['rancid_version'] = '3';" >> /.OBSERVIUM/Production/observium/config.php

# Configurer les tâches cron pour Observium
RUN echo "33  */6   * * *   root    /.OBSERVIUM/Production/observium/observium-wrapper discovery >> /dev/null 2>&1\n\
*/5 *     * * *   root    /.OBSERVIUM/Production/observium/observium-wrapper discovery --host new >> /dev/null 2>&1\n\
*/5 *     * * *   root    /.OBSERVIUM/Production/observium/observium-wrapper poller >> /dev/null 2>&1\n\
13 5 * * * root /.OBSERVIUM/Production/observium/housekeeping.php -ysel >> /dev/null 2>&1\n\
47 4 * * * root /.OBSERVIUM/Production/observium/housekeeping.php -yrptb >> /dev/null 2>&1" > /etc/cron.d/observium

# Exposer les ports necessaire
EXPOSE 80 161/udp 162/udp

# Définir un volume pour MariaDB
VOLUME /var/lib/mysql

# Lancer Apache, MariaDB et cron en arrière-plan
CMD service mariadb start && service apache2 start && cron && tail -f /var/log/apache2/access.log
