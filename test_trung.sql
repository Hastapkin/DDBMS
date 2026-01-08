-- SITE 1 — LINK_TRUNG (Product.1, Order.1, Customer Local, Supplier.1 & .2)
-- Test 1.1 — Insert product into Product.1
BEGIN
    AddProduct(10, 'Site1_A', 1, 1000);
END;
/

-- Expected:
-- Row appears in product_frag1.
-- product_id between 1–29
-- product_name = Site1_A
-- price = 1000

-- Test 1.2 — Insert customer into local copy
INSERT INTO customer_local(customer_id, customer_name, customer_mobile, customer_email)
VALUES(101, 'Alice', '0901', 'a@test');
/

-- Expected:
-- Customer appears with total_payment = 0.

-- Test 1.3 — Create order → Trigger calculates price & total
BEGIN
    AddOrder(1001, 1, 101, 3, 'Hanoi');
END;
/
SELECT * FROM orders_frag1 WHERE customer_id = 101;
SELECT * FROM customer_local WHERE customer_id = 101;

-- Expected:
-- product_price auto filled
-- total_cost = price * 3
-- customer_local.total_payment increased

-- Test 1.4 — Search product (local only)
BEGIN
    SearchProduct('Site1');
END;
/

-- Test 1.5 — Delete order → Trigger subtracts from total
DELETE FROM orders_frag1 WHERE orders_id = 1001;
SELECT total_payment FROM customer_local WHERE customer_id = 101;

-- Expected: total_payment decreases.

SELECT * FROM product_frag1;

COMMIT;
