#!/bin/bash
# sync.sh — MariaDB → MongoDB Data Pipeline
# Runs: Clean → Extract → Load

# 1: Clean: Delete the old JSON files from /var/lib/mysql-files/.

sudo rm -f /var/lib/mysql-files/*.json


# 2: Extract: Run your json.sql script against MariaDB to generate fresh JSON files.

sudo mariadb < /home/tmarley/json.sql


# 3: Load: Run mongoimport for all four collections using the --drop flag (which drops the old collection before importing the new data, ensuring a clean refresh).

mongoimport --db POS --collection Products \
--file /var/lib/mysql-files//prod.json --drop

mongoimport --db POS --collection Customers \
--file /var/lib/mysql-files//cust.json --drop

mongoimport --db POS --collection Custom1 \
--file /var/lib/mysql-files//custom1.json --drop

mongoimport --db POS --collection Custom2 \
--file /var/lib/mysql-files//custom2.json --drop


