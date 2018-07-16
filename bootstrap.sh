#!/bin/bash

# Used to provision the server on the Vagrant virtual machine

# By default, Vagrant mounts the folder with the Vagrantfile (project root) to /vagrant
# So source our environment variables from this folder

set -a;
source /vagrant/.env

sudo apt-get update

# Install Python 2.7
sudo apt-get install -y python

# Install Apache
sudo apt-get install -y apache2

# Copy our custom Apache configuration settings
sudo cp "${PROJECT_DIR}apache2/mods-enabled/dir.conf" "/etc/apache2/mods-enabled/dir.conf"
sudo cp "${PROJECT_DIR}apache2/apache2.conf" "/etc/apache2/apache2.conf"
sudo cp "${PROJECT_DIR}apache2/sites-available/000-default.conf" "/etc/apache2/sites-available/000-default.conf"


# Change the Apache user to vagrant
sudo sed -i "s/APACHE_RUN_USER=www-data/APACHE_RUN_USER=vagrant/g" /etc/apache2/envvars
sudo sed -i "s/APACHE_RUN_GROUP=www-data/APACHE_RUN_GROUP=vagrant/g" /etc/apache2/envvars

# Enable Rewrite Module
sudo ln -s "/etc/apache2/mods-available/rewrite.load" "/etc/apache2/mods-enabled/rewrite.load"

# Configure Ubuntu firewall to allow incoming traffic to "Apache Full"
sudo ufw allow in "Apache Full"




## Install MySQL

# debconf-set-sections allows for non-interactive installation (responds to questions that MySQL asks automatically)
# <<< is herestring, which feeds the string to stdin of the previous command
sudo debconf-set-selections <<< "mysql-server mysql-server/root-password password ${DB_PASS}"
sudo debconf-set-selections <<< "mysql-server mysql-server/root-password_again password ${DB_PASS}"

# Flag for debian to know we intend to run the program in a noninteractive way
sudo DEBIAN_FRONTEND=noninteractive apt-get -y install mysql-server

# Stop the server
sudo systemctl stop mysql

# Change the owner of files in the datadir that were already created
sudo chown -R vagrant:vagrant $MYSQL_DATADIR

# Also make them writable by anyone
sudo chmod -R a=rwx $MYSQL_DATADIR

# In MySQL configuration file, change the unix user of mysql to 'vagrant'
# (this will prevent permissions conflicts betwen mysqld and git in the future)
sudo sed -i "s/= mysql/= vagrant/g" /etc/mysql/mysql.conf.d/mysqld.cnf

# Restart mysql server and enable it to autostart
sudo systemctl start mysql
sudo systemctl enable mysql







## Install PHP
sudo apt-get install -y php libapache2-mod-php php-mysql php-cli php7.0-gd



# Reload Apache2 after configuration changes and enable it to start on boot
# Reload configuration changes
sudo systemctl reload apache2

# Enable the server to automatically startup on boot
sudo systemctl enable apache2


## Zip Utility
apt-get install zip unzip




# Install WP CLI
curl -O https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar
chmod +x wp-cli.phar
sudo mv wp-cli.phar /usr/bin/wp

# Install wp dist-archive package
wp package install wp-cli/dist-archive-command


## WordPress Setup


# Double quotes necessary to avoid the \ (escape newline) combining
# into variables which are strings.
${PROJECT_DIR}bash-scripts/create-multisite.sh \
  "$MULTISITE_DIR" \
  "$DB_NAME" \
  "$DB_USER" \
  "$DB_PASS" \
  "$SITE_URL" \
  "$SITE_TITLE" \
  "$WP_SUPERADMIN_USER" \
  "$WP_SUPERADMIN_PASSWORD" \
  "$WP_ADMIN_EMAIL"

# Setup the local copy of commons blogs
${PROJECT_DIR}bash-scripts/create-multisite.sh \
  "$COMMONS_BLOGS_DIR" \
  "$CB_DB_NAME" \
  "$CB_DB_USER" \
  "$CB_DB_PASS" \
  "$CB_SITE_URL" \
  "$CB_SITE_TITLE" \
  "$WP_SUPERADMIN_USER" \
  "$WP_SUPERADMIN_PASSWORD" \
  "$WP_ADMIN_EMAIL"

# Populate the uploads directory of Commons Blogs
${PROJECT_DIR}bash-scripts/create-dummy-image-for-every-blog.sh


echo You must obtain a CNDLS-HALO-TEST database dump from Marie or CNDLS administrator \
and upload it to the database using: sudo mysql --database="$CB_DB_NAME" < blogs.sql

echo blogs.sql is the name of the database export file
