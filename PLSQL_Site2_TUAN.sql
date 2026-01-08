-- LINK_TUAN_SITE2.sql
-- Site: LINK_TUAN (Site 2)
-- This site holds Product.2, Order.2, Customer (master), Supplier.1, etc.

-- Sequences removed; IDs must be provided explicitly.

-- 2. Product fragment (Product.2)  : 30 <= product_id < 60
CREATE TABLE product_frag2 (
  product_id NUMBER PRIMARY KEY,
  product_name VARCHAR2(100),
  supplier_id NUMBER,
  price NUMBER
);

-- 3. Orders fragment (Order.2) : 30 <= product_id < 60
CREATE TABLE orders_frag2 (
  orders_id NUMBER PRIMARY KEY,
  product_id NUMBER,
  customer_id NUMBER,
  order_location VARCHAR2(50),
  quantity NUMBER,
  product_price NUMBER,
  total_cost NUMBER,
  ordered_at VARCHAR2(50)
);

-- 4. Customer master
CREATE TABLE customer (
  customer_id NUMBER PRIMARY KEY,
  customer_name VARCHAR2(100),
  customer_mobile VARCHAR2(20),
  customer_email VARCHAR2(100),
  total_payment NUMBER DEFAULT 0
);

-- 5. Supplier.1 vertical fragment (present on all sites)
CREATE TABLE supplier_frag1 (
  supplier_id NUMBER PRIMARY KEY,
  supplier_name VARCHAR2(50),
  location VARCHAR2(100)
);


-- 7. Function: countpriceproductinsite (local)
CREATE OR REPLACE FUNCTION countpriceproductinsite(p_prod_id NUMBER) RETURN NUMBER IS
  v_price NUMBER;
BEGIN
  SELECT price INTO v_price FROM product_frag2 WHERE product_id = p_prod_id;
  RETURN v_price;
EXCEPTION
  WHEN NO_DATA_FOUND THEN
    RETURN NULL;
END;
/

-- 8. Procedures (same names; operate on local fragments)
CREATE OR REPLACE PROCEDURE AddProduct(
  p_prod_id IN NUMBER, p_name IN VARCHAR2, p_supplier_id IN NUMBER, p_price IN NUMBER
) IS
BEGIN
  IF p_prod_id < 30 OR p_prod_id >= 60 THEN
    RAISE_APPLICATION_ERROR(-20031, 'Product_id must be in Site2 range (30..59).');
  END IF;
  INSERT INTO product_frag2(product_id, product_name, supplier_id, price)
  VALUES(p_prod_id, p_name, p_supplier_id, p_price);
  COMMIT;
END;
/

-- Thay thế thủ tục AddOrder cũ trong file PLSQL_Site2_TUAN.sql
CREATE OR REPLACE PROCEDURE AddOrder(
  p_orders_id IN NUMBER,
  p_product_id IN NUMBER,
  p_customer_id IN NUMBER,
  p_quantity IN NUMBER,
  p_order_location IN VARCHAR2
) IS
  v_price NUMBER;
  v_total NUMBER;
BEGIN
  -- CASE 1: Sản phẩm thuộc Site 1 (Remote - TRUNG)
  IF p_product_id >= 1 AND p_product_id < 30 THEN
      -- Gọi thủ tục từ xa
      AddOrder@LINK_TRUNG(p_orders_id, p_product_id, p_customer_id, p_quantity, p_order_location);

  -- CASE 2: Sản phẩm thuộc Site 2 (Local)
  ELSIF p_product_id >= 30 AND p_product_id < 60 THEN
      SELECT price INTO v_price FROM product_frag2 WHERE product_id = p_product_id;
      v_total := v_price * p_quantity;

      INSERT INTO orders_frag2(orders_id, product_id, customer_id, order_location, quantity, product_price, total_cost)
      VALUES(p_orders_id, p_product_id, p_customer_id, p_order_location, p_quantity, v_price, v_total);

      -- Update Customer Master tại đây (vì đây là Site 2)
      UPDATE customer SET total_payment = NVL(total_payment,0) + v_total WHERE customer_id = p_customer_id;
      IF SQL%ROWCOUNT = 0 THEN
        RAISE_APPLICATION_ERROR(-20010, 'Customer not found in master (LINK_TUAN)');
      END IF;
      COMMIT;

  -- CASE 3: Sản phẩm thuộc Site 3 (Remote - SON)
  ELSIF p_product_id >= 60 AND p_product_id < 90 THEN
      -- Gọi thủ tục từ xa
      AddOrder@LINK_SON(p_orders_id, p_product_id, p_customer_id, p_quantity, p_order_location);

  ELSE
      RAISE_APPLICATION_ERROR(-20033, 'Product_id khong hop le (Out of global range).');
  END IF;
END;
/

-- 9. Trigger: On insert to orders_frag2 calculate costs (similar to site1)
CREATE OR REPLACE TRIGGER trg_calc_order_cost_ins2
BEFORE INSERT ON orders_frag2
FOR EACH ROW
DECLARE
  v_price NUMBER;
BEGIN
  IF :NEW.product_price IS NULL THEN
    SELECT price INTO v_price FROM product_frag2 WHERE product_id = :NEW.product_id;
    :NEW.product_price := v_price;
  END IF;
  IF :NEW.total_cost IS NULL THEN
    :NEW.total_cost := :NEW.product_price * NVL(:NEW.quantity,1);
  END IF;

  -- update master customer table
  UPDATE customer SET total_payment = NVL(total_payment,0) + :NEW.total_cost WHERE customer_id = :NEW.customer_id;
  IF SQL%ROWCOUNT = 0 THEN
    RAISE_APPLICATION_ERROR(-20011, 'Customer not found in master (LINK_TUAN) during trigger');
  END IF;
END;
/

-- 10. Trigger: Before delete subtract from master
CREATE OR REPLACE TRIGGER trg_update_total_payment_delete2
BEFORE DELETE ON orders_frag2
FOR EACH ROW
BEGIN
  UPDATE customer SET total_payment = NVL(total_payment,0) - NVL(:OLD.total_cost,0) WHERE customer_id = :OLD.customer_id;
  IF SQL%ROWCOUNT = 0 THEN
    RAISE_APPLICATION_ERROR(-20012, 'Customer not found in master (LINK_TUAN) during delete');
  END IF;
END;
/

-- 11. SearchProduct procedure (master aggregates)
CREATE OR REPLACE PROCEDURE SearchProduct(p_name IN VARCHAR2) IS
BEGIN
  FOR r IN (SELECT 'SITE2' site, product_id, product_name, price FROM product_frag2 WHERE LOWER(product_name) LIKE '%'||LOWER(p_name)||'%') LOOP
    DBMS_OUTPUT.PUT_LINE('ID:'||r.product_id||' NAME:'||r.product_name||' PRICE:'||r.price);
  END LOOP;
END;
/

-- Supplier procedures or other utilities can be added here (mirror of site1)

-- End of LINK_TUAN script
