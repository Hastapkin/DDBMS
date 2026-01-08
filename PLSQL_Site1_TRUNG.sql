-- LINK_TRUNG_SITE1.sql
-- Site: LINK_TRUNG (Site 1)
-- Creates schema objects for Product.1, Order.1, Customer (local copy), Supplier fragments, sequences, procedures, triggers.
-- NOTE: Replace DB link connection strings (create public database links) with real connect strings/credentials.

-- 1. Create user (optional, or run as schema owner)
-- CREATE USER link_trung IDENTIFIED BY change_me;
-- GRANT CONNECT, RESOURCE TO link_trung;

-- Assume running as link_trung

-- Sequences removed; IDs must be provided explicitly.

-- 3. Product fragment (Product.1)  : condition 1 < product_id < 30
CREATE TABLE product_frag1 (
  product_id NUMBER PRIMARY KEY,
  product_name VARCHAR2(100),
  supplier_id NUMBER,
  price NUMBER
);

-- 4. Orders fragment (Order.1) : 1 < product_id < 30
CREATE TABLE orders_frag1 (
  orders_id NUMBER PRIMARY KEY,
  product_id NUMBER,
  customer_id NUMBER,
  order_location VARCHAR2(50),
  quantity NUMBER,
  product_price NUMBER,
  total_cost NUMBER,
  ordered_at VARCHAR2(50)
);

-- 5. Customer (local copy). Master is at LINK_TUAN (Site2) but a local copy exists here per allocation
CREATE TABLE customer_local (
  customer_id NUMBER PRIMARY KEY,
  customer_name VARCHAR2(100),
  customer_mobile VARCHAR2(20),
  customer_email VARCHAR2(100),
  total_payment NUMBER DEFAULT 0
);

-- 6. Supplier vertical fragments
-- Supplier.1 : Supplier_id, Supplier_name, location
CREATE TABLE supplier_frag1 (
  supplier_id NUMBER PRIMARY KEY,
  supplier_name VARCHAR2(50),
  location VARCHAR2(100)
);

-- Supplier.2 exists at Site1 as per vertical fragmentation (phone, contact_person, address, email)
CREATE TABLE supplier_frag2 (
  supplier_id NUMBER PRIMARY KEY,
  phone VARCHAR2(50),
  contact_person VARCHAR2(100),
  address VARCHAR2(200),
  email VARCHAR2(100)
);

-- 7. Indexes / FK placeholders (FKs to products/suppliers/customers are logical; DB links used for cross-site)
-- (Add constraints if you maintain referential integrity locally)
-- Example:
-- ALTER TABLE orders_frag1 ADD CONSTRAINT fk_orders1_product FOREIGN KEY (product_id) REFERENCES product_frag1(product_id);

-- 8. PUBLIC DB LINKS (examples) - COMMENTED. Replace username/password@connect_identifier.
-- CREATE PUBLIC DATABASE LINK LINK_TUAN_DB CONNECT TO link_tuan IDENTIFIED BY password USING 'tns_alias_to_site2';
-- CREATE PUBLIC DATABASE LINK LINK_SON_DB  CONNECT TO link_son  IDENTIFIED BY password USING 'tns_alias_to_site3';

-- 9. Function: countpriceproductinsite (returns price if product exists locally)
CREATE OR REPLACE FUNCTION countpriceproductinsite(p_prod_id NUMBER) RETURN NUMBER IS
  v_price NUMBER;
BEGIN
  SELECT price INTO v_price FROM product_frag1 WHERE product_id = p_prod_id;
  RETURN v_price;
EXCEPTION
  WHEN NO_DATA_FOUND THEN
    RETURN NULL;
END;
/

-- 10. Procedure: AddProduct (adds into local fragment)
CREATE OR REPLACE PROCEDURE AddProduct(
  p_prod_id IN NUMBER,
  p_name IN VARCHAR2,
  p_supplier_id IN NUMBER,
  p_price IN NUMBER
) IS
BEGIN
  IF p_prod_id < 1 OR p_prod_id >= 30 THEN
    RAISE_APPLICATION_ERROR(-20001, 'Product_id must be in Site1 range (1..29).');
  END IF;
  INSERT INTO product_frag1(product_id, product_name, supplier_id, price)
  VALUES(p_prod_id, p_name, p_supplier_id, p_price);
  COMMIT;
END;
/

-- 11. Procedure: AddOrder (insert into local orders fragment)
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
  -- CASE 1: Sản phẩm thuộc Site 1 (Local)
  IF p_product_id >= 1 AND p_product_id < 30 THEN
      -- Lấy giá và tính toán nội bộ như cũ
      SELECT price INTO v_price FROM product_frag1 WHERE product_id = p_product_id;
      v_total := v_price * p_quantity;

      INSERT INTO orders_frag1(orders_id, product_id, customer_id, order_location, quantity, product_price, total_cost)
      VALUES(p_orders_id, p_product_id, p_customer_id, p_order_location, p_quantity, v_price, v_total);
      
      -- Trigger trg_calc_order_cost_ins sẽ tự động chạy để update customer_local
      COMMIT;

  -- CASE 2: Sản phẩm thuộc Site 2 (Remote - TUAN)
  ELSIF p_product_id >= 30 AND p_product_id < 60 THEN
      -- Gọi thủ tục từ xa qua DB Link
      -- Giả định DB Link tên là LINK_TUAN_DB (bạn cần thay đúng tên DB Link bạn đã tạo)
      AddOrder@LINK_TUAN(p_orders_id, p_product_id, p_customer_id, p_quantity, p_order_location);
      
  -- CASE 3: Sản phẩm thuộc Site 3 (Remote - SON)
  ELSIF p_product_id >= 60 AND p_product_id < 90 THEN
      -- Gọi thủ tục từ xa qua DB Link
      -- Giả định DB Link tên là LINK_SON_DB
      AddOrder@LINK_SON(p_orders_id, p_product_id, p_customer_id, p_quantity, p_order_location);

  ELSE
      RAISE_APPLICATION_ERROR(-20002, 'Product_id khong hop le (Out of global range).');
  END IF;
END;
/

-- 12. Procedure: SearchProduct (local/global search)
CREATE OR REPLACE PROCEDURE SearchProduct(p_name IN VARCHAR2) IS
  CURSOR c_local IS
    SELECT 'SITE1' site, product_id, product_name, price FROM product_frag1 WHERE LOWER(product_name) LIKE '%'||LOWER(p_name)||'%';
  v_row c_local%ROWTYPE;
BEGIN
  DBMS_OUTPUT.PUT_LINE('--- SITE1 RESULTS ---');
  OPEN c_local;
  LOOP
    FETCH c_local INTO v_row;
    EXIT WHEN c_local%NOTFOUND;
    DBMS_OUTPUT.PUT_LINE('ID:'||v_row.product_id||' NAME:'||v_row.product_name||' PRICE:'||v_row.price);
  END LOOP;
  CLOSE c_local;
END;
/

-- 13. Trigger: calculate_order_cost & update_total_payment_insert
-- This trigger calculates product_price and total_cost on insert and then updates master Customer at LINK_TUAN via DB link.

CREATE OR REPLACE TRIGGER trg_calc_order_cost_ins
BEFORE INSERT ON orders_frag1
FOR EACH ROW
DECLARE
  v_price NUMBER;
  v_new_total NUMBER;
BEGIN
  -- compute price from local product fragment if not provided
  IF :NEW.product_price IS NULL THEN
    SELECT price INTO v_price FROM product_frag1 WHERE product_id = :NEW.product_id;
    :NEW.product_price := v_price;
  ELSE
    v_price := :NEW.product_price;
  END IF;

  IF :NEW.total_cost IS NULL THEN
    :NEW.total_cost := v_price * NVL(:NEW.quantity,1);
  END IF;

  -- Update local customer copy
  BEGIN
    UPDATE customer_local
    SET total_payment = NVL(total_payment,0) + :NEW.total_cost
    WHERE customer_id = :NEW.customer_id;
    IF SQL%ROWCOUNT = 0 THEN
      -- insert local copy if doesn't exist
      INSERT INTO customer_local(customer_id, customer_name, total_payment)
      VALUES(:NEW.customer_id, NULL, :NEW.total_cost);
    END IF;
  EXCEPTION WHEN OTHERS THEN
    NULL;
  END;
END;
/

-- 14. Trigger: update_total_payment_delete (Before delete subtract cost from master)
CREATE OR REPLACE TRIGGER trg_update_total_payment_delete
BEFORE DELETE ON orders_frag1
FOR EACH ROW
BEGIN
  -- Subtract from local customer copy
  BEGIN
    UPDATE customer_local
    SET total_payment = NVL(total_payment,0) - NVL(:OLD.total_cost,0)
    WHERE customer_id = :OLD.customer_id;
  EXCEPTION WHEN OTHERS THEN
    NULL;
  END;
END;
/

-- 15. Supplier management procedures (Add_Supplier, Delete_Supplier, Update_Supplier)
CREATE OR REPLACE PROCEDURE Add_Supplier(
  p_supplier_id IN NUMBER,
  p_name IN VARCHAR2,
  p_location IN VARCHAR2,
  p_phone IN VARCHAR2,
  p_contact IN VARCHAR2,
  p_address IN VARCHAR2,
  p_email IN VARCHAR2
) IS
BEGIN
  IF p_supplier_id < 1 THEN
    RAISE_APPLICATION_ERROR(-20003, 'Supplier_id must be positive and provided explicitly.');
  END IF;
  INSERT INTO supplier_frag1(supplier_id, supplier_name, location)
   VALUES(p_supplier_id, p_name, p_location);
  INSERT INTO supplier_frag2(supplier_id, phone, contact_person, address, email)
   VALUES(p_supplier_id, p_phone, p_contact, p_address, p_email);
  COMMIT;
END;
/

CREATE OR REPLACE PROCEDURE Delete_Supplier(p_supplier_id IN NUMBER) IS
BEGIN
  DELETE FROM supplier_frag2 WHERE supplier_id = p_supplier_id;
  DELETE FROM supplier_frag1 WHERE supplier_id = p_supplier_id;
  COMMIT;
END;
/

CREATE OR REPLACE PROCEDURE Update_Supplier(
  p_supplier_id IN NUMBER,
  p_name IN VARCHAR2,
  p_location IN VARCHAR2,
  p_phone IN VARCHAR2,
  p_contact IN VARCHAR2,
  p_address IN VARCHAR2,
  p_email IN VARCHAR2
) IS
BEGIN
  UPDATE supplier_frag1 SET supplier_name = p_name, location = p_location WHERE supplier_id = p_supplier_id;
  UPDATE supplier_frag2 SET phone = p_phone, contact_person = p_contact, address = p_address, email = p_email WHERE supplier_id = p_supplier_id;
  COMMIT;
END;
/

-- 16. Utility: CountTypeProduct (example counts products by price range)
CREATE OR REPLACE PROCEDURE CountTypeProduct IS
  v_count NUMBER;
BEGIN
  SELECT COUNT(*) INTO v_count FROM product_frag1;
  DBMS_OUTPUT.PUT_LINE('Product count at SITE1: ' || v_count);
END;
/

-- End of LINK_TRUNG script

COMMIT;