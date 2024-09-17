<?php

## Database config
// --- This MUST be configured
$config['db_host']      = 'mariadb';  // Nom du service ou de l'hôte de la base de données
$config['db_name']      = 'observium';     // Nom de la base de données
$config['db_user']      = 'admin';     // Utilisateur de la base de données
$config['db_pass']      = 'adminpassword'; // Mot de passe de l'utilisateur de la base de données

// Base directory
#$config['install_dir'] = "/opt/observium";

// Default SNMP version
#$config['snmp']['version'] = "v2c";

// Enable alerter
#$config['poller-wrapper']['alerter'] = TRUE;

// RANCID integration
$config['rancid_configs'][] = "/var/lib/rancid/observium/configs/";
$config['rancid_ignorecomments'] = 0;
$config['rancid_version'] = '3';

