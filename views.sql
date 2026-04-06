##########################################################################
# POS Views and Triggers
# Creates v_ProductBuyers, mv_ProductBuyers, and supporting triggers
##########################################################################


SOURCE /home/tmarley/etl.sql;

USE POS;

DROP TRIGGER IF EXISTS trg_orderline_ai_mv_productbuyers;
DROP TRIGGER IF EXISTS trg_orderline_ad_mv_productbuyers;
DROP TRIGGER IF EXISTS trg_product_au_pricehistory;

DROP TABLE IF EXISTS mv_ProductBuyers;
DROP VIEW IF EXISTS v_ProductBuyers;


CREATE VIEW v_ProductBuyers AS
SELECT
    p.id AS productID,
    p.name AS productName,
    IFNULL(
        GROUP_CONCAT(
            DISTINCT CONCAT(c.id, ' ', c.firstName, ' ', c.lastName)
            ORDER BY c.id
            SEPARATOR ', '
        ),
        ''
    ) AS customers
FROM Product p
LEFT JOIN Orderline ol
    ON ol.product_id = p.id
LEFT JOIN `Order` o
    ON o.id = ol.order_id
LEFT JOIN Customer c
    ON c.id = o.customer_id
GROUP BY
    p.id,
    p.name
ORDER BY
    p.id;


CREATE TABLE mv_ProductBuyers AS
SELECT
    productID,
    productName,
    customers
FROM v_ProductBuyers;


ALTER TABLE mv_ProductBuyers
    ADD INDEX idx_mv_ProductBuyers_productID (productID);

DELIMITER $$

CREATE TRIGGER trg_orderline_ai_mv_productbuyers
AFTER INSERT ON Orderline
FOR EACH ROW
BEGIN
    UPDATE mv_ProductBuyers mv
    SET
        mv.productName = (SELECT p.name FROM Product p WHERE p.id = NEW.product_id),
        mv.customers =
            (
                SELECT
                IFNULL(
                        GROUP_CONCAT(
                            DISTINCT CONCAT(c.id, ' ', c.firstName, ' ', c.lastName)
                            ORDER BY c.id
                            SEPARATOR ', '
                        ),
                        ''
                    )
                FROM Orderline ol
                JOIN `Order` o
                    ON o.id = ol.order_id
                JOIN Customer c
                    ON c.id = o.customer_id
                WHERE ol.product_id = NEW.product_id
            )
    WHERE mv.productID = NEW.product_id;
END$$


CREATE TRIGGER trg_orderline_ad_mv_productbuyers
AFTER DELETE ON Orderline
FOR EACH ROW
BEGIN
    UPDATE mv_ProductBuyers mv
    SET
        mv.productName = (SELECT p.name FROM Product p WHERE p.id = OLD.product_id),
        mv.customers =
            (
                SELECT
                    IFNULL(
                        GROUP_CONCAT(
                            DISTINCT CONCAT(c.id, ' ', c.firstName, ' ', c.lastName)
                            ORDER BY c.id
                            SEPARATOR ', '
                        ),
                        ''
                    )
                FROM Orderline ol
                JOIN `Order` o
                    ON o.id = ol.order_id
                JOIN Customer c
                    ON c.id = o.customer_id
                WHERE ol.product_id = OLD.product_id
            )
    WHERE mv.productID = OLD.product_id;
END$$


CREATE TRIGGER trg_product_au_pricehistory
AFTER UPDATE ON Product
FOR EACH ROW
BEGIN
    IF NOT (OLD.currentPrice <=> NEW.currentPrice) THEN
        INSERT INTO PriceHistory (oldPrice, newPrice, product_id)
        VALUES (OLD.currentPrice, NEW.currentPrice, OLD.id);
    END IF;
END$$

DELIMITER ;
