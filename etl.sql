##########################################################################
# POS ETL Script
# Builds schema and loads CSV data into POS database
##########################################################################


DROP DATABASE IF EXISTS POS;
CREATE DATABASE POS;
USE POS;

CREATE TABLE City (
    zip DECIMAL(5,0) ZEROFILL PRIMARY KEY,
    city VARCHAR(32),
    state VARCHAR(4)
);

CREATE TABLE Customer (
    id SERIAL PRIMARY KEY,
    firstName VARCHAR(32),
    lastName VARCHAR(30),
    email VARCHAR(128),
    address1 VARCHAR(100),
    address2 VARCHAR(50),
    phone VARCHAR(32),
    birthdate DATE,
    zip DECIMAL(5,0) ZEROFILL,
    CONSTRAINT fk_customer_city FOREIGN KEY (zip) REFERENCES City(zip)
);

CREATE TABLE `Order` (
    id SERIAL PRIMARY KEY,
    datePlaced DATE,
    dateShipped DATE,
    customer_id BIGINT UNSIGNED,
    CONSTRAINT fk_order_customer FOREIGN KEY (customer_id) REFERENCES Customer(id)
);

CREATE TABLE Product (
    id SERIAL PRIMARY KEY,
    name VARCHAR(128),
    currentPrice DECIMAL(6,2),
    availableQuantity INT
);

CREATE TABLE Orderline (
    order_id BIGINT UNSIGNED,
    product_id BIGINT UNSIGNED,
    quantity INT,
    PRIMARY KEY (order_id, product_id),
    CONSTRAINT fk_orderline_order FOREIGN KEY (order_id) REFERENCES `Order`(id),
    CONSTRAINT fk_orderline_product FOREIGN KEY (product_id) REFERENCES Product(id)
);

CREATE TABLE PriceHistory (
    id SERIAL PRIMARY KEY,
    oldPrice DECIMAL(6,2),
    newPrice DECIMAL(6,2),
    ts TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    product_id BIGINT UNSIGNED,
    CONSTRAINT fk_pricehistory_product FOREIGN KEY (product_id) REFERENCES Product(id)
);

DROP TABLE IF EXISTS stg_customers;
DROP TABLE IF EXISTS stg_products;
DROP TABLE IF EXISTS stg_orders;
DROP TABLE IF EXISTS stg_orderlines;

CREATE TABLE stg_customers (
    ID VARCHAR(32),
    FN VARCHAR(255),
    LN VARCHAR(255),
    CT VARCHAR(255),
    ST VARCHAR(32),
    ZP VARCHAR(32),
    S1 VARCHAR(255),
    S2 VARCHAR(255),
    EM VARCHAR(255),
    BD VARCHAR(255)
);

CREATE TABLE stg_products (
    ID VARCHAR(32),
    Name VARCHAR(255),
    Price VARCHAR(64),
    QtyOnHand VARCHAR(32)
);

CREATE TABLE stg_orders (
    OID VARCHAR(32),
    CID VARCHAR(32),
    Ordered VARCHAR(255),
    Shipped VARCHAR(255)
);

CREATE TABLE stg_orderlines (
    OID VARCHAR(32),
    PID VARCHAR(32)
);

LOAD DATA LOCAL INFILE '/home/tmarley/734003123/customers.csv'
INTO TABLE stg_customers
FIELDS TERMINATED BY ',' ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 LINES;

LOAD DATA LOCAL INFILE '/home/tmarley/734003123/products.csv'
INTO TABLE stg_products
FIELDS TERMINATED BY ',' ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 LINES;

LOAD DATA LOCAL INFILE '/home/tmarley/734003123/orders.csv'
INTO TABLE stg_orders
FIELDS TERMINATED BY ',' ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 LINES;

LOAD DATA LOCAL INFILE '/home/tmarley/734003123/orderlines.csv'
INTO TABLE stg_orderlines
FIELDS TERMINATED BY ',' ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 LINES;

INSERT INTO City (zip, city, state)
SELECT DISTINCT
    CAST(LPAD(TRIM(ZP), 5, '0') AS UNSIGNED),
    NULLIF(TRIM(CT), ''),
    NULLIF(TRIM(ST), '')
FROM stg_customers
WHERE TRIM(ZP) <> '';

INSERT INTO Customer (id, firstName, lastName, email, address1, address2, phone, birthdate, zip)
SELECT
    CAST(TRIM(ID) AS UNSIGNED),
    NULLIF(TRIM(FN), ''),
    NULLIF(TRIM(LN), ''),
    NULLIF(TRIM(EM), ''),
    NULLIF(TRIM(S1), ''),
    NULLIF(TRIM(S2), ''),
    NULL,
    CASE
        WHEN TRIM(BD) = '' THEN NULL
        WHEN TRIM(BD) IN ('0000-00-00','00/00/0000') THEN NULL
        WHEN BD LIKE '%/%/%' THEN STR_TO_DATE(BD, '%m/%d/%Y')
        WHEN BD LIKE '%-%-%' THEN STR_TO_DATE(BD, '%Y-%m-%d')
        ELSE NULL
    END,
    CAST(LPAD(TRIM(ZP), 5, '0') AS UNSIGNED)
FROM stg_customers;

INSERT INTO `Order` (id, datePlaced, dateShipped, customer_id)
SELECT
    CAST(TRIM(OID) AS UNSIGNED),
    CASE
        WHEN TRIM(Ordered) = '' THEN NULL
        WHEN TRIM(Ordered) IN ('0000-00-00','00/00/0000') THEN NULL
        WHEN Ordered REGEXP '^[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2}$' THEN DATE(STR_TO_DATE(Ordered, '%Y-%m-%d %H:%i:%s'))
        WHEN Ordered REGEXP '^[0-9]{4}-[0-9]{2}-[0-9]{2}$' THEN STR_TO_DATE(Ordered, '%Y-%m-%d')
        WHEN Ordered REGEXP '^[0-9]{1,2}/[0-9]{1,2}/[0-9]{4} [0-9]{2}:[0-9]{2}:[0-9]{2}$' THEN DATE(STR_TO_DATE(Ordered, '%m/%d/%Y %H:%i:%s'))
        WHEN Ordered REGEXP '^[0-9]{1,2}/[0-9]{1,2}/[0-9]{4}$' THEN STR_TO_DATE(Ordered, '%m/%d/%Y')
        ELSE NULL
    END,
    CASE
        WHEN TRIM(Shipped) = '' THEN NULL
        WHEN TRIM(Shipped) IN ('0000-00-00','00/00/0000') THEN NULL
        WHEN Shipped REGEXP '^[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2}$' THEN DATE(STR_TO_DATE(Shipped, '%Y-%m-%d %H:%i:%s'))
        WHEN Shipped REGEXP '^[0-9]{4}-[0-9]{2}-[0-9]{2}$' THEN STR_TO_DATE(Shipped, '%Y-%m-%d')
        WHEN Shipped REGEXP '^[0-9]{1,2}/[0-9]{1,2}/[0-9]{4} [0-9]{2}:[0-9]{2}:[0-9]{2}$' THEN DATE(STR_TO_DATE(Shipped, '%m/%d/%Y %H:%i:%s'))
        WHEN Shipped REGEXP '^[0-9]{1,2}/[0-9]{1,2}/[0-9]{4}$' THEN STR_TO_DATE(Shipped, '%m/%d/%Y')
        ELSE NULL	
    END,
    CAST(TRIM(CID) AS UNSIGNED)
FROM stg_orders;

INSERT INTO Product (id, name, currentPrice, availableQuantity)
SELECT
    CAST(TRIM(ID) AS UNSIGNED),
    NULLIF(TRIM(Name), ''),
    CAST(REPLACE(REPLACE(REPLACE(TRIM(Price), '$', ''), ',', ''), ' ', '') AS DECIMAL(6,2)),
    CAST(NULLIF(TRIM(QtyOnHand), '') AS SIGNED)
FROM stg_products;

INSERT INTO Orderline (order_id, product_id, quantity)
SELECT
    CAST(TRIM(OID) AS UNSIGNED),
    CAST(TRIM(PID) AS UNSIGNED),
    COUNT(*) AS quantity
FROM stg_orderlines
WHERE TRIM(OID) <> '' AND TRIM(PID) <> ''
GROUP BY CAST(TRIM(OID) AS UNSIGNED), CAST(TRIM(PID) AS UNSIGNED);

DROP TABLE IF EXISTS stg_customers;
DROP TABLE IF EXISTS stg_products;
DROP TABLE IF EXISTS stg_orders;
DROP TABLE IF EXISTS stg_orderlines;

