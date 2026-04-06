##########################################################################
# JSON export
# Creates prod.json, cust.json, custom1.json, and custom2.json
##########################################################################

USE POS;

SET SESSION group_concat_max_len = 10000000;

# =============================================================================
# Case 1: Product Aggregate  →  prod.json
# =============================================================================
SELECT JSON_OBJECT(
    'ProductID', p.id,
    'currentPrice', p.currentPrice,
    'productName', p.name,
    'customers',
    COALESCE(
        (
            SELECT JSON_ARRAYAGG(
                JSON_OBJECT(
                    'CustomerID', c.id,
                    'Customer Name', CONCAT(c.firstName, ' ', c.lastName)
                )
            )
            FROM Customer c
            WHERE EXISTS (
                SELECT 1
                FROM Orderline ol
                JOIN `Order` o
                ON o.id = ol.order_id
                WHERE ol.product_id = p.id
                AND o.customer_id = c.id
            )
        ),
        JSON_ARRAY()
    )
)
INTO OUTFILE '/var/lib/mysql-files/prod.json'
FIELDS TERMINATED BY ''
ESCAPED BY ''
LINES TERMINATED BY '\n'
FROM Product p;

# =============================================================================
# Case 2: Deep Customer Aggregate  →  cust.json
# =============================================================================
SELECT JSON_OBJECT(
    'customer_name', CONCAT(c.firstName, ' ', c.lastName),
    'printed_address_1',
    CASE
    WHEN c.address2 IS NULL OR TRIM(c.address2) = ''
    THEN c.address1
    ELSE CONCAT(c.address1, ' #', c.address2)
    END,
    'printed_address_2',
    CONCAT(ci.city, ', ', ci.state, '   ', LPAD(ci.zip, 5, '0')),
    'Orders',
    COALESCE(
        (
            SELECT JSON_ARRAYAGG(
                JSON_OBJECT(
                    'Order Total',
                    (
                        SELECT COALESCE(SUM(p.currentPrice * ol.quantity), 0)
                        FROM Orderline ol
                        JOIN Product p
                        ON p.id = ol.product_id
                        WHERE ol.order_id = o.id
                    ),
                    'Order Date', o.datePlaced,
                    'Shipping Date', o.dateShipped,
                    'Items',
                    COALESCE(
                        (
                            SELECT JSON_ARRAYAGG(
                                JSON_OBJECT(
                                    'Product ID', p.id,
                                    'Quantity', ol.quantity,
                                    'Product Name', p.name
                                )
                            )
                            FROM Orderline ol
                            JOIN Product p
                            ON p.id = ol.product_id
                            WHERE ol.order_id = o.id
                        ),
                        JSON_ARRAY()
                    )
                )
            )
            FROM `Order` o
            WHERE o.customer_id = c.id
        ),
        JSON_ARRAY()
    )
)
INTO OUTFILE '/var/lib/mysql-files/cust.json'
FIELDS TERMINATED BY ''
ESCAPED BY ''
LINES TERMINATED BY '\n'
FROM Customer c
LEFT JOIN City ci
ON ci.zip = c.zip;

# =============================================================================
# Case 3: Regional Delivery Manifest  →  custom1.json
# =============================================================================
CREATE INDEX IF NOT EXISTS idx_order_dateshipped_customer ON `Order` (dateShipped, customer_id);
CREATE INDEX IF NOT EXISTS idx_orderline_order_product ON Orderline (order_id, product_id);
CREATE INDEX IF NOT EXISTS idx_customer_zip ON Customer (zip);
CREATE INDEX IF NOT EXISTS idx_city_zip_state ON City (zip, state);

SELECT JSON_OBJECT(
    'shipping_date', grp.dateShipped,
    'state', grp.state,
    'orders',
    COALESCE(
        (
            SELECT JSON_ARRAYAGG(
                JSON_OBJECT(
                    'OrderID', o.id,
                    'customer_name', CONCAT(c.firstName, ' ', c.lastName),
                    'printed_address_1',
                    CASE
                    WHEN c.address2 IS NULL OR TRIM(c.address2) = ''
                    THEN c.address1
                    ELSE CONCAT(c.address1, ' #', c.address2)
                    END,
                    'printed_address_2',
                    CONCAT(ci.city, ', ', ci.state, '   ', LPAD(ci.zip, 5, '0')),
                    'order_total',
                    (
                        SELECT COALESCE(SUM(p.currentPrice * ol.quantity), 0)
                        FROM Orderline ol
                        JOIN Product p
                        ON p.id = ol.product_id
                        WHERE ol.order_id = o.id
                    ),
                    'items',
                    COALESCE(
                        (
                            SELECT JSON_ARRAYAGG(
                                JSON_OBJECT(
                                    'ProductID', p.id,
                                    'productName', p.name,
                                    'quantity', ol.quantity
                                )
                            )
                            FROM Orderline ol
                            JOIN Product p
                            ON p.id = ol.product_id
                            WHERE ol.order_id = o.id
                        ),
                        JSON_ARRAY()
                    )
                )
            )
            FROM `Order` o
            JOIN Customer c
            ON c.id = o.customer_id
            JOIN City ci
            ON ci.zip = c.zip
            WHERE o.dateShipped = grp.dateShipped
            AND ci.state = grp.state
        ),
        JSON_ARRAY()
    )
)
INTO OUTFILE '/var/lib/mysql-files/custom1.json'
FIELDS TERMINATED BY ''
ESCAPED BY ''
LINES TERMINATED BY '\n'
FROM (
    SELECT DISTINCT
    o.dateShipped,
    ci.state
    FROM `Order` o
    JOIN Customer c
    ON c.id = o.customer_id
    JOIN City ci
    ON ci.zip = c.zip
    WHERE o.dateShipped IS NOT NULL
) AS grp;

# =============================================================================
# Case 4: Monthly Product Demand Planning  →  custom2.json
# =============================================================================
CREATE INDEX IF NOT EXISTS idx_order_date_customer ON `Order` (datePlaced, customer_id);
CREATE INDEX IF NOT EXISTS idx_orderline_product_order ON Orderline (product_id, order_id);
CREATE INDEX IF NOT EXISTS idx_product_id ON Product (id);
CREATE INDEX IF NOT EXISTS idx_customer_id ON Customer (id);

SELECT JSON_OBJECT(
    'month', m.order_month,
    'products',
    COALESCE(
        (
            SELECT JSON_ARRAYAGG(
                JSON_OBJECT(
                    'ProductID', p.id,
                    'productName', p.name,
                    'total_units_ordered',
                    COALESCE(
                        (
                            SELECT SUM(ol.quantity)
                            FROM `Order` o
                            JOIN Orderline ol
                            ON ol.order_id = o.id
                            WHERE DATE_FORMAT(o.datePlaced, '%Y-%m') = m.order_month
                            AND ol.product_id = p.id
                        ),
                        0
                    ),
                    'total_revenue',
                    COALESCE(
                        (
                            SELECT SUM(p2.currentPrice * ol.quantity)
                            FROM `Order` o
                            JOIN Orderline ol
                            ON ol.order_id = o.id
                            JOIN Product p2
                            ON p2.id = ol.product_id
                            WHERE DATE_FORMAT(o.datePlaced, '%Y-%m') = m.order_month
                            AND ol.product_id = p.id
                        ),
                        0
                    ),
                    'customers',
                    COALESCE(
                        (
                            SELECT JSON_ARRAYAGG(
                                JSON_OBJECT(
                                    'CustomerID', c.id,
                                    'customer_name', CONCAT(c.firstName, ' ', c.lastName),
                                    'orders',
                                    COALESCE(
                                        (
                                            SELECT JSON_ARRAYAGG(
                                                JSON_OBJECT(
                                                    'OrderID', o.id,
                                                    'Order Date', o.datePlaced,
                                                    'Quantity', ol.quantity,
                                                    'Line Total', (p3.currentPrice * ol.quantity)
                                                )
                                            )
                                            FROM `Order` o
                                            JOIN Orderline ol
                                            ON ol.order_id = o.id
                                            JOIN Product p3
                                            ON p3.id = ol.product_id
                                            WHERE DATE_FORMAT(o.datePlaced, '%Y-%m') = m.order_month
                                            AND ol.product_id = p.id
                                            AND o.customer_id = c.id
                                        ),
                                        JSON_ARRAY()
                                    )
                                )
                            )
                            FROM Customer c
                            WHERE EXISTS (
                                SELECT 1
                                FROM `Order` o
                                JOIN Orderline ol
                                ON ol.order_id = o.id
                                WHERE DATE_FORMAT(o.datePlaced, '%Y-%m') = m.order_month
                                AND ol.product_id = p.id
                                AND o.customer_id = c.id
                            )
                        ),
                        JSON_ARRAY()
                    )
                )
            )
            FROM Product p
            WHERE EXISTS (
                SELECT 1
                FROM `Order` o
                JOIN Orderline ol
                ON ol.order_id = o.id
                WHERE DATE_FORMAT(o.datePlaced, '%Y-%m') = m.order_month
                AND ol.product_id = p.id
            )
        ),
        JSON_ARRAY()
    )
)
INTO OUTFILE '/var/lib/mysql-files/custom2.json'
FIELDS TERMINATED BY ''
ESCAPED BY ''
LINES TERMINATED BY '\n'
FROM (
    SELECT DISTINCT DATE_FORMAT(datePlaced, '%Y-%m') AS order_month
    FROM `Order`
    WHERE datePlaced IS NOT NULL
) AS m;