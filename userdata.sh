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

apt-get install -y apt-transport-https ca-certificates curl
mkdir -p /etc/apt/keyrings
curl -o /etc/apt/keyrings/mariadb-keyring.pgp 'https://mariadb.org/mariadb_release_signing_key.pgp'

cat > /etc/apt/sources.list.d/mariadb.sources <<'EOF'
X-Repolib-Name: MariaDB
Types: deb
URIs: https://mirrors.accretive-networks.net/mariadb/repo/11.8/ubuntu
Suites: noble
Components: main main/debug
Signed-By: /etc/apt/keyrings/mariadb-keyring.pgp
EOF

export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install mariadb-server -y

if [ $? -eq 0 ];
then    touch /root/info--5-MariaDB-Installed;
else    touch /root/info--5-MariaDB_Installation-FAILED--END; exit 1; fi

systemctl enable mariadb
systemctl start mariadb
systemctl is-active --quiet mariadb

if [ $? -eq 0 ];
then    touch /root/info--6-MariaDB_ServiceRunning;
else    touch /root/info--6-MariaDB_FAILED--ServiceNotRunning--EXIT; exit 1; fi

##########################################################################
#                  Create user and install tools
##########################################################################
useradd -m -s /bin/bash tmarley
echo "tmarley:Passw0rdisthebestpassw0rd" | chpasswd

apt-get install unzip -y
apt-get install -y openssl

##########################################################################
# Assignment Data Import
##########################################################################
sudo -u tmarley wget -O /home/tmarley/734003123.zip https://622.gomillion.org/data/734003123.zip
sudo -u tmarley mkdir -p /home/tmarley/734003123
sudo -u tmarley unzip -o /home/tmarley/734003123.zip -d /home/tmarley/734003123

##########################################################################
# Download SQL scripts
##########################################################################
ETL_URL="https://raw.githubusercontent.com/tjzmarley/ITSM622/main/etl.sql"
JSON_URL="https://raw.githubusercontent.com/tjzmarley/ITSM622/main/json.sql"

sudo -u tmarley wget -O /home/tmarley/etl.sql  "$ETL_URL"
sudo -u tmarley wget -O /home/tmarley/json.sql "$JSON_URL"

##########################################################################
# POS DB User Setup
##########################################################################
DB_USER="tmarley"
DB_PASS="DBPassword"

mariadb -u root <<EOF
CREATE USER IF NOT EXISTS '${DB_USER}'@'localhost' IDENTIFIED BY '${DB_PASS}';
GRANT CREATE, SELECT, INSERT, UPDATE, DELETE, INDEX, ALTER, DROP ON POS.* TO '${DB_USER}'@'localhost';
FLUSH PRIVILEGES;
EOF

cat >/home/tmarley/.my.cnf <<EOF
[client]
user=tmarley
password=${DB_PASS}
local-infile=1
EOF
chown tmarley:tmarley /home/tmarley/.my.cnf
chmod 600 /home/tmarley/.my.cnf

##########################################################################
# Execute ETL then JSON export
##########################################################################
mariadb -u root -e "SET GLOBAL local_infile = 1;"

sudo -u tmarley mariadb --local-infile=1 < /home/tmarley/etl.sql

if [ $? -eq 0 ];
then    touch /root/info--7-ETL_Complete;
else    touch /root/info--7-ETL_FAILED--EXIT; exit 1; fi

sudo -u tmarley mariadb < /home/tmarley/json.sql

if [ $? -eq 0 ];
then    touch /root/info--8-JSON_Export_Complete;
else    touch /root/info--8-JSON_Export_FAILED; fi

touch /root/info--9-UserData_Complete
