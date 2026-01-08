-- 2) SITE 2 — LINK_TUAN (Product.2, Order.2, Customer MASTER)
-- Test 2.1 — Insert product into Product.2
BEGIN
  AddProduct(35, 'Site2_A', 2, 2000);
END;
/
SELECT * FROM product_frag2;

-- Expected:
-- product_id between 30–59.

-- Test 2.2 — Create master customer
INSERT INTO customer(customer_id, customer_name, customer_mobile, customer_email)
VALUES(201, 'Bob', '0902', 'b@test');
SELECT * FROM customer;

-- Test 2.3 — Create order → auto-price + master update
BEGIN
  AddOrder(2001, 35, 201, 5, 'Da Nang');
END;
/
SELECT * FROM orders_frag2;
SELECT * FROM customer WHERE customer_id = 201;

-- Expected:
-- customer.total_payment = price * 5

-- Test 2.4 — Trigger check (manual insert)
INSERT INTO orders_frag2(orders_id, product_id, customer_id, quantity)
VALUES(999, 35, 201, 2);

SELECT * FROM orders_frag2 WHERE orders_id = 999;
SELECT total_payment FROM customer WHERE customer_id = 201;

-- Test 2.5 — Search product
BEGIN
  SearchProduct('Site2');
END;
/

DELETE FROM product_frag2;
DELETE FROM orders_frag2;
DELETE FROM supplier_frag1;
DELETE FROM customer;

COMMIT;




@PLSQL_Site2_TUAN.sql   -- or just recompile
ALTER PROCEDURE AddOrder COMPILE;