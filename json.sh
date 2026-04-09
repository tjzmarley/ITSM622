#!/bin/bash

exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1

##########################################################################
#     Updates and Upgrades installed default packages with validation
##########################################################################
touch /root/info--1-BeginUpdatingPackages;

if apt update;
then    touch /root/info--2-PackagesUpdated;
else    touch /root/info--2-PackageUpdates-FAILED--continuing; fi

if apt upgrade -y;
then    touch /root/info--3-PackagesUpgraded;
else    touch /root/info--3-PackageUpgrdes-FAILED--continuing; fi

##########################################################################
#                  Begin MariaDB installation
##########################################################################
touch /root/info--4-BeginMariaDBInstallation;

# Part One
apt-get install -y apt-transport-https ca-certificates curl
mkdir -p /etc/apt/keyrings
curl -o /etc/apt/keyrings/mariadb-keyring.pgp 'https://mariadb.org/mariadb_release_signing_key.pgp'

# Part Two
cat > /etc/apt/sources.list.d/mariadb.sources <<'EOF'
# MariaDB 11.8 repository list - created 2026-02-11 02:40 UTC
# https://mariadb.org/download/
X-Repolib-Name: MariaDB
Types: deb
# deb.mariadb.org is a dynamic mirror if your preferred mirror goes offline. See https://mariadb.org/mirrorbits/ for details.
# URIs: https://deb.mariadb.org/11.8/ubuntu
URIs: https://mirrors.accretive-networks.net/mariadb/repo/11.8/ubuntu
Suites: noble
Components: main main/debug
Signed-By: /etc/apt/keyrings/mariadb-keyring.pgp
EOF

# Part Three
export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install mariadb-server -y

##########################################################################
#                 Validating installation of MariaDB
##########################################################################
if [ $? -eq 0 ];
then    touch /root/info--5-MariaDB-Installed;
else    touch /root/info--5-MariaDB_Installation-FAILED--END; exit 1; fi

##########################################################################
#                 Enabling MariaDB and starting services
##########################################################################
systemctl enable mariadb
systemctl start mariadb
systemctl is-active --quiet mariadb

##########################################################################
#                Validating MariaDB services running
##########################################################################
if [ $? -eq 0 ];
then    touch /root/info--5-MariaDB_ServiceRunning;
else    touch /root/info--5-MariaDB_FAILED--ServiceNotRunning--EXIT; exit 1; fi

# End MariaDB installation

##########################################################################
#                  Begin MongoDB installation
##########################################################################
# Install MongoDb dependencies
sudo apt-get install -y libcurl4 libgssapi-krb5-2 libldap2 libwrap0 libsasl2-2 libsasl2-modules libsasl2-modules-gssapi-mit openssl liblzma5

# Download the tarball


# OR us the package manager
#
# DISTRIB_ID=Ubuntu
# DISTRIB_RELEASE=24.04
# DISTRIB_CODENAME=noble
# DISTRIB_DESCRIPTION="Ubuntu 24.04.4 LTS"

# Import the public key
#
# From a terminal, install gnupg and curl if they are not already available:
sudo apt-get install gnupg curl
# To import the MongoDB public GPG key, run the following command:
curl -fsSL https://pgp.mongodb.com/server-8.0.asc | \
sudo gpg -o /usr/share/keyrings/mongodb-server-8.0.gpg \
--dearmor

# Create the list file
#
# Create the list file /etc/apt/sources.list.d/mongodb-org-8.2.list for your version of Ubuntu.
echo "deb [ arch=amd64,arm64 signed-by=/usr/share/keyrings/mongodb-server-8.0.gpg ] https://repo.mongodb.org/apt/ubuntu noble/mongodb-org/8.2 multiverse" | sudo tee /etc/apt/sources.list.d/mongodb-org-8.2.list

# Reload the package database
#
# Issue the following command to reload the local package database:
sudo apt-get update

# Install MongoDB Community Server.
#
# You can install either the latest stable version of MongoDB or a specific version of MongoDB.
sudo apt-get install -y mongodb-org


# ulimit Considerations
# Most Unix-like operating systems limit the system resources that a process may use. These limits may negatively impact MongoDB operation, and should be adjusted. See UNIX ulimit Settings for Self-Managed Deployments for the recommended settings for your platform.

# Directories
# If you installed through the package manager, the data directory /var/lib/mongodb and the log directory /var/log/mongodb are created during the installation.

# By default, MongoDB runs using the mongodb user account. If you change the user that runs the MongoDB process, you must also modify the permission to the data and log directories to give this user access to these directories.

# Configuration File
# The official MongoDB package includes a configuration file (/etc/mongod.conf). These settings (such as the data directory and log directory specifications) take effect upon startup. That is, if you change the configuration file while the MongoDB instance is running, you must restart the instance for the changes to take effect.

# Procedure
# Follow these steps to run MongoDB Community Edition on your system. These instructions assume that you are using the official mongodb-org package -- not the unofficial mongodb package provided by Ubuntu -- and are using the default settings.

# Init System
# To run and manage your mongod process, use your operating system's built-in init system. Recent versions of Linux use systemd, which uses the systemctl command, while older versions of Linux use System V init, which uses the service command.

# If you are unsure which init system your platform uses, run the following command:
# ps --no-headers -o comm 1

# 1. Start MongoDB.
#    You can start the mongod process by issuing the following command:
sudo systemctl start mongod
#    If you receive an error similar to the following when starting mongod:
#    Failed to start mongod.service: Unit mongod.service not found.

#    Run the following command first:
sudo systemctl daemon-reload

#    Then run the start command above again.
sudo systemctl start mongod


# 2. Verify that MongoDB has started successfully.
sudo systemctl status mongod
#    You can optionally ensure that MongoDB will start following a system reboot by issuing the following command:
sudo systemctl enable mongod

# 3. Stop MongoDB.
#    As needed, you can stop the mongod process by issuing the following command:
sudo systemctl stop mongod

# 4. Restart MongoDB
#    You can restart the mongod process by issuing the following command:
sudo systemctl restart mongod
#    You can follow the state of the process for errors or important messages by watching the output in the /var/log/mongodb/mongod.log file.

# 5. Begin using MongoDB.
#   Start a mongosh session on the same host machine as the mongod. You can run mongosh without any command-line options to connect to a mongod that is running on your localhost with default port 27017.
mongosh
#    For more information on connecting using mongosh, such as to connect to a mongod instance running on a different host and/or port, see the mongosh documentation.
#   To help you start using MongoDB, MongoDB provides Getting Started Guides in various driver editions. For the driver documentation, see Start Developing with MongoDB.


# End MongoDB installation



# create a standard non-privleged linux user
useradd -m -s /bin/bash tmarley
echo "tmarley:Passw0rdisthebestpassw0rd" | chpasswd

# Get packages to ready to unzip files and create secure Password
apt-get install unzip -y
apt-get install -y openssl


##########################################################################
# Assignment Data Import
# Downloads and extracts CSV dataset
##########################################################################

# Import assignment data
sudo -u tmarley wget -O /home/tmarley/734003123.zip https://622.gomillion.org/data/734003123.zip
sudo -u tmarley mkdir -p /home/tmarley/734003123
sudo -u tmarley unzip -o /home/tmarley/734003123.zip -d /home/tmarley/734003123


##########################################################################
# POS DB User Setup
# Creates user and stores credentials
##########################################################################

#Define DB user variables
DB_USER="tmarley"
DB_PASS="DBPassword"

# Create the DB user and set permissions
mariadb -u root <<EOF
CREATE USER IF NOT EXISTS '${DB_USER}'@'localhost' IDENTIFIED BY '${DB_PASS}';
GRANT CREATE, SELECT, INSERT, UPDATE, DELETE, INDEX, ALTER, DROP, CREATE VIEW, SHOW VIEW, TRIGGER
ON POS.* TO '${DB_USER}'@'localhost';
FLUSH PRIVILEGES;
EOF

#Create and save credentials for interactive login
cat >/home/tmarley/.my.cnf <<EOF
[client]
user=tmarley
password=${DB_PASS}
local-infile=1
EOF
chown tmarley:tmarley /home/tmarley/.my.cnf
chmod 600 /home/tmarley/.my.cnf

##########################################################################
# Download the sql files
##########################################################################

sudo -u tmarley wget -O /home/tmarley/etl.sql \
https://raw.githubusercontent.com/tjzmarley/ITSM622/main/etl.sql
chown tmarley:tmarley /home/tmarley/etl.sql

sudo -u tmarley wget -O /home/tmarley/views.sql \
https://raw.githubusercontent.com/tjzmarley/ITSM622/main/views.sql
chown tmarley:tmarley /home/tmarley/views.sql

sudo -u tmarley wget -O /home/tmarley/json.sql \
https://raw.githubusercontent.com/tjzmarley/ITSM622/main/json.sql
chown mysql:mysql /home/tmarley/json.sql

##########################################################################
# Execute the sql files
##########################################################################

# Execute the views.sql file
mariadb -u root -e "SET GLOBAL local_infile = 1;"
sudo -u tmarley mariadb --local-infile=1 < /home/tmarley/views.sql
if [ $? -eq 0 ];
then    touch /root/info--6-views_sql_executed;
else    touch /root/info--6-views_sql_FAILED--EXIT; exit 1; fi

# Create the directory for the exported .json files
mkdir -p /var/lib/mysql-files
chown mysql:mysql /var/lib/mysql-files

# Execute the json.sql file
sudo mariadb < /home/tmarley/json.sql
if [ $? -eq 0 ];
then    touch /root/info--7-json_sql_executed;
else    touch /root/info--7-json_sql_FAILED--EXIT; exit 1; fi



# Sync script
# Download script
sudo -u tmarley wget -O /home/tmarley/sync.sh \
https://raw.githubusercontent.com/tjzmarley/ITSM622/main/sync.sh
# Set permissions
chmod 755 /home/tmarley/sync.sh


(crontab -l 2>/dev/null; echo "*/2 * * * * /home/tmarley/sync.sh >> /home/tmarley/sync.log 2>&1") | crontab -
if [ $? -eq 0 ];
then    touch /root/info--8-cronjob_scheduled;
else    touch /root/info--8-cronjob_FAILED--EXIT; exit 1; fi
