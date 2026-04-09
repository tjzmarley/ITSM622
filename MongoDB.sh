#!/bin/bash

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


