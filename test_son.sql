-- 3) SITE 3 — LINK_SON (Product.3, Order.3, Customer Local)
-- Test 3.1 — Insert product into Product.3
BEGIN
  AddProduct(70, 'Site3_A', 3, 3000);
END;
/
SELECT * FROM product_frag3;

-- Expected product_id 60–89.

-- Test 3.2 — Insert local customer
INSERT INTO customer_local(customer_id, customer_name)
VALUES(301, 'Charlie');

-- Test 3.3 — Create order → Trigger fills price + total
BEGIN
  AddOrder(3001, 70, 301, 4, 'HCM');
END;
/
SELECT * FROM orders_frag3;
SELECT * FROM customer_local WHERE customer_id = 301;

-- Expected:
-- total_payment updated.

-- Test 3.4 — Delete order
DELETE FROM orders_frag3 WHERE orders_id = 3001;
SELECT * FROM customer_local WHERE customer_id = 301;

-- Test 3.5 — Search product
BEGIN
  SearchProduct('Site3');
END;
/

DELETE FROM CUSTOMER_LOCAL;
DELETE FROM ORDERS_FRAG3;
DELETE FROM PRODUCT_FRAG3;
DELETE FROM SUPPLIER_FRAG1;
COMMIT;