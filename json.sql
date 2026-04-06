-- =============================================================================
-- json.sql
-- JSON Milestone: Export POS data as NDJSON for MongoDB ingestion
-- Course: ISTM 622 – Advanced Data Management
-- =============================================================================
-- Run after etl.sql or views.sql has built and populated the POS database.
-- Output files land in /var/lib/mysql-files/ (MariaDB's secure_file_priv dir).
-- Each file is NDJSON: one valid JSON object per line, no wrapping array.
-- =============================================================================

USE POS;

-- ---------------------------------------------------------------------------
-- Case 1: Product Aggregate  →  prod.json
-- Root: { productID, productName, currentPrice, customers: [ {id, name}, … ] }
-- ---------------------------------------------------------------------------
SELECT JSON_OBJECT(
    'productID',    p.id,
    'productName',  p.name,
    'currentPrice', p.currentPrice,
    'customers',    IFNULL(
                        JSON_ARRAYAGG(
                            JSON_OBJECT(
                                'customerID',   c.id,
                                'customerName', CONCAT(c.firstName, ' ', c.lastName)
                            )
                        ),
                        JSON_ARRAY()
                    )
)
FROM Product p
LEFT JOIN Orderline ol ON ol.product_id = p.id
LEFT JOIN `Order`   o  ON o.id          = ol.order_id
LEFT JOIN Customer  c  ON c.id          = o.customer_id
GROUP BY p.id, p.name, p.currentPrice
ORDER BY p.id
INTO OUTFILE '/var/lib/mysql-files/prod.json'
LINES TERMINATED BY '\n';


-- ---------------------------------------------------------------------------
-- Case 2: Deep Customer Aggregate  →  cust.json
-- Root: { customer_name, printed_address_1, printed_address_2,
--         orders: [ { orderTotal, orderDate, shippedDate,
--                     items: [ {productID, productName, quantity}, … ] } ] }
-- ---------------------------------------------------------------------------
-- Build bottom-up: items CTE → orders CTE → outer customer SELECT.
-- ---------------------------------------------------------------------------
SELECT JSON_OBJECT(
    'customerID',       c.id,
    'customer_name',    CONCAT(c.firstName, ' ', c.lastName),

    -- address line 1: append "# <addr2>" only when address2 is not null/empty
    'printed_address_1',
        CASE
            WHEN NULLIF(TRIM(c.address2), '') IS NULL
                THEN c.address1
            ELSE CONCAT(c.address1, ' # ', c.address2)
        END,

    -- address line 2: "City, State   Zip"  (three spaces between state and zip)
    'printed_address_2',
        CONCAT(
            ci.city, ', ', ci.state, '   ',
            LPAD(c.zip, 5, '0')
        ),

    -- orders array (built via correlated subquery to avoid GROUP BY conflicts)
    'orders', (
        SELECT IFNULL(
            JSON_ARRAYAGG(
                JSON_OBJECT(
                    'orderID',     o.id,
                    'orderDate',   DATE_FORMAT(o.datePlaced,  '%Y-%m-%d'),
                    'shippedDate', DATE_FORMAT(o.dateShipped, '%Y-%m-%d'),
                    'orderTotal',  (
                        SELECT ROUND(SUM(p2.currentPrice * ol2.quantity), 2)
                        FROM   Orderline ol2
                        JOIN   Product   p2 ON p2.id = ol2.product_id
                        WHERE  ol2.order_id = o.id
                    ),
                    'items', (
                        SELECT IFNULL(
                            JSON_ARRAYAGG(
                                JSON_OBJECT(
                                    'productID',   p3.id,
                                    'productName', p3.name,
                                    'quantity',    ol3.quantity
                                )
                            ),
                            JSON_ARRAY()
                        )
                        FROM   Orderline ol3
                        JOIN   Product   p3 ON p3.id = ol3.product_id
                        WHERE  ol3.order_id = o.id
                    )
                )
            ),
            JSON_ARRAY()
        )
        FROM `Order` o
        WHERE o.customer_id = c.id
    )
)
FROM Customer c
JOIN City ci ON ci.zip = c.zip
ORDER BY c.id
INTO OUTFILE '/var/lib/mysql-files/cust.json'
LINES TERMINATED BY '\n';


-- ---------------------------------------------------------------------------
-- Case 3 (Custom): Regional Sales Summary  →  custom1.json
-- Business Pitch:
--   The regional sales VP needs a single-read view per state showing
--   total revenue, number of customers, and the top products sold in
--   that region — without hitting the OLTP database. This drives the
--   regional marketing dashboard and helps allocate delivery logistics.
--
-- Root: { state, customerCount, totalRevenue,
--         topProducts: [ {productID, productName, unitsSold, revenue}, … ] }
-- ---------------------------------------------------------------------------
SELECT JSON_OBJECT(
    'state',         ci.state,
    'customerCount', COUNT(DISTINCT c.id),
    'totalRevenue',  ROUND(SUM(p.currentPrice * ol.quantity), 2),
    'topProducts', (
        SELECT IFNULL(
            JSON_ARRAYAGG(
                JSON_OBJECT(
                    'productID',   sub.pid,
                    'productName', sub.pname,
                    'unitsSold',   sub.units,
                    'revenue',     sub.rev
                )
            ),
            JSON_ARRAY()
        )
        FROM (
            SELECT
                p2.id                                    AS pid,
                p2.name                                  AS pname,
                SUM(ol2.quantity)                        AS units,
                ROUND(SUM(p2.currentPrice * ol2.quantity), 2) AS rev
            FROM Customer  c2
            JOIN City      ci2 ON ci2.zip        = c2.zip
            JOIN `Order`   o2  ON o2.customer_id = c2.id
            JOIN Orderline ol2 ON ol2.order_id   = o2.id
            JOIN Product   p2  ON p2.id          = ol2.product_id
            WHERE ci2.state = ci.state
            GROUP BY p2.id, p2.name
            ORDER BY units DESC
            LIMIT 5
        ) sub
    )
)
FROM Customer  c
JOIN City      ci ON ci.zip        = c.zip
JOIN `Order`   o  ON o.customer_id = c.id
JOIN Orderline ol ON ol.order_id   = o.id
JOIN Product   p  ON p.id         = ol.product_id
GROUP BY ci.state
ORDER BY ci.state
INTO OUTFILE '/var/lib/mysql-files/custom1.json'
LINES TERMINATED BY '\n';


-- ---------------------------------------------------------------------------
-- Case 4 (Custom): Price-Change Audit Trail  →  custom2.json
-- Business Pitch:
--   The pricing team and auditors need a complete "price story" for every
--   product: current price, how many times it changed, and the full
--   chronological history of changes. Storing this as a MongoDB document
--   means any microservice (e-commerce, mobile, ERP) can pull a product's
--   entire pricing history in one query without joining PriceHistory each
--   time. Enables instant price-transparency features and regulatory audits.
--
-- Root: { productID, productName, currentPrice, changeCount,
--         priceHistory: [ {changedAt, oldPrice, newPrice, delta}, … ] }
-- ---------------------------------------------------------------------------
SELECT JSON_OBJECT(
    'productID',    p.id,
    'productName',  p.name,
    'currentPrice', p.currentPrice,
    'changeCount',  (
        SELECT COUNT(*) FROM PriceHistory ph2 WHERE ph2.product_id = p.id
    ),
    'priceHistory', (
        SELECT IFNULL(
            JSON_ARRAYAGG(
                JSON_OBJECT(
                    'changedAt', DATE_FORMAT(ph.ts, '%Y-%m-%d %H:%i:%s'),
                    'oldPrice',  ph.oldPrice,
                    'newPrice',  ph.newPrice,
                    'delta',     ROUND(ph.newPrice - ph.oldPrice, 2)
                )
                ORDER BY ph.ts
            ),
            JSON_ARRAY()
        )
        FROM PriceHistory ph
        WHERE ph.product_id = p.id
    )
)
FROM Product p
ORDER BY p.id
INTO OUTFILE '/var/lib/mysql-files/custom2.json'
LINES TERMINATED BY '\n';
