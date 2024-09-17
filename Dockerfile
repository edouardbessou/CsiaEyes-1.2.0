# Utiliser l'image de base Debian
FROM debian:12
MAINTAINER Edouard Bessou

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
    nano \
    libvirt-clients \
    rancid \
    cron \
    && apt-get clean

# Configurer le ServerName dans Apache pour éviter les avertissements
RUN echo "ServerName localhost" >> /etc/apache2/apache2.conf

# Télécharger et installer Observium
RUN mkdir -p /opt/observium && cd /opt \
    && wget http://www.observium.org/observium-community-latest.tar.gz \
    && tar zxvf observium-community-latest.tar.gz \
    && mv observium-community-* observium

# Créer les répertoires requis par Observium
RUN cd /opt/observium \
    && mkdir logs rrd \
    && chown www-data:www-data rrd logs

# Copier le fichier config.php dans le bon répertoire
COPY config.php opt/observium/config.php

# Configurer Apache pour servir Observium
RUN echo '<VirtualHost *:80>\n\
    ServerAdmin webmaster@localhost\n\
    DocumentRoot /opt/observium/html\n\
    <Directory />\n\
        Options FollowSymLinks\n\
        AllowOverride None\n\
    </Directory>\n\
    <Directory /opt/observium/html/>\n\
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
RUN echo "\$config['rancid_configs'][] = \"/var/lib/rancid/observium/configs/\";" >> /opt/observium/config.php \
    && echo "\$config['rancid_ignorecomments'] = 0;" >> /opt/observium/config.php \
    && echo "\$config['rancid_version'] = '3';" >> /opt/observium/config.php

# Configurer les tâches cron pour Observium
RUN echo "33  */6   * * *   root    /opt/observium/observium-wrapper discovery >> /dev/null 2>&1\n\
*/5 *     * * *   root    /opt/observium/observium-wrapper discovery --host new >> /dev/null 2>&1\n\
*/5 *     * * *   root    /opt/observium/observium-wrapper poller >> /dev/null 2>&1\n\
13 5 * * * root /opt/observium/housekeeping.php -ysel >> /dev/null 2>&1\n\
47 4 * * * root /opt/observium/housekeeping.php -yrptb >> /dev/null 2>&1" > /etc/cron.d/observium

# Exposer les ports nécessaires
EXPOSE 80 161/udp 162/udp

# Lancer Apache et cron en arrière-plan
CMD service apache2 start && cron && tail -f /var/log/apache2/access.log
