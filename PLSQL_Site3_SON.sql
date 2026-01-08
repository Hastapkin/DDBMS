-- LINK_SON_SITE3.sql
-- Site: LINK_SON (Site 3)
-- Holds Product.3, Order.3, Customer (local copy), Supplier.1

-- Sequences removed; IDs must be provided explicitly.

-- 2. Product fragment (Product.3) : 60 <= product_id < 90
CREATE TABLE product_frag3 (
  product_id NUMBER PRIMARY KEY,
  product_name VARCHAR2(100),
  supplier_id NUMBER,
  price NUMBER
);

-- 3. Orders fragment (Order.3)
CREATE TABLE orders_frag3 (
  orders_id NUMBER PRIMARY KEY,
  product_id NUMBER,
  customer_id NUMBER,
  order_location VARCHAR2(50),
  quantity NUMBER,
  product_price NUMBER,
  total_cost NUMBER,
  ordered_at VARCHAR2(50)
);

-- 4. Customer local copy
CREATE TABLE customer_local (
  customer_id NUMBER PRIMARY KEY,
  customer_name VARCHAR2(100),
  customer_mobile VARCHAR2(20),
  customer_email VARCHAR2(100),
  total_payment NUMBER DEFAULT 0
);

-- 5. Supplier.1 vertical fragment
CREATE TABLE supplier_frag1 (
  supplier_id NUMBER PRIMARY KEY,
  supplier_name VARCHAR2(50),
  location VARCHAR2(100)
);


-- 7. Function: countpriceproductinsite
CREATE OR REPLACE FUNCTION countpriceproductinsite(p_prod_id NUMBER) RETURN NUMBER IS
  v_price NUMBER;
BEGIN
  SELECT price INTO v_price FROM product_frag3 WHERE product_id = p_prod_id;
  RETURN v_price;
EXCEPTION
  WHEN NO_DATA_FOUND THEN
    RETURN NULL;
END;
/

-- 8. Procedures: AddProduct, AddOrder, SearchProduct (mirror)
CREATE OR REPLACE PROCEDURE AddProduct(
  p_prod_id IN NUMBER, p_name IN VARCHAR2, p_supplier_id IN NUMBER, p_price IN NUMBER
) IS
BEGIN
  IF p_prod_id < 60 OR p_prod_id >= 90 THEN
    RAISE_APPLICATION_ERROR(-20061, 'Product_id must be in Site3 range (60..89).');
  END IF;
  INSERT INTO product_frag3(product_id, product_name, supplier_id, price)
  VALUES(p_prod_id, p_name, p_supplier_id, p_price);
  COMMIT;
END;
/

CREATE OR REPLACE PROCEDURE AddOrder(
  p_orders_id IN NUMBER,
  p_product_id IN NUMBER,
  p_customer_id IN NUMBER,
  p_quantity IN NUMBER,
  p_order_location IN VARCHAR2
) IS
  v_price NUMBER;
  v_total NUMBER;
  v_sql VARCHAR2(1000); -- Biến chứa câu lệnh động
BEGIN
  -- CASE 1: Sản phẩm thuộc Site 1 (Remote - TRUNG)
  IF p_product_id >= 1 AND p_product_id < 30 THEN
      -- Sử dụng Dynamic SQL để tránh kiểm tra dependency lúc compile
      v_sql := 'BEGIN AddOrder@LINK_TRUNG_DB(:1, :2, :3, :4, :5); END;';
      EXECUTE IMMEDIATE v_sql USING p_orders_id, p_product_id, p_customer_id, p_quantity, p_order_location;

  -- CASE 2: Sản phẩm thuộc Site 2 (Remote - TUAN)
  ELSIF p_product_id >= 30 AND p_product_id < 60 THEN
      v_sql := 'BEGIN AddOrder@LINK_TUAN_DB(:1, :2, :3, :4, :5); END;';
      EXECUTE IMMEDIATE v_sql USING p_orders_id, p_product_id, p_customer_id, p_quantity, p_order_location;

  -- CASE 3: Sản phẩm thuộc Site 3 (Local)
  ELSIF p_product_id >= 60 AND p_product_id < 90 THEN
      SELECT price INTO v_price FROM product_frag3 WHERE product_id = p_product_id;
      v_total := v_price * p_quantity;
      
      INSERT INTO orders_frag3(orders_id, product_id, customer_id, order_location, quantity, product_price, total_cost)
        VALUES(p_orders_id, p_product_id, p_customer_id, p_order_location, p_quantity, v_price, v_total);

      -- Update local customer copy tại Site 3
      UPDATE customer_local SET total_payment = NVL(total_payment,0) + v_total WHERE customer_id = p_customer_id;
      IF SQL%ROWCOUNT = 0 THEN
        INSERT INTO customer_local(customer_id, customer_name, total_payment) VALUES(p_customer_id, NULL, v_total);
      END IF;
      COMMIT;

  ELSE
      RAISE_APPLICATION_ERROR(-20063, 'Product_id khong hop le (Out of global range).');
  END IF;
END;
/

-- 9. Procedure: SearchProduct (local search)
CREATE OR REPLACE PROCEDURE SearchProduct(p_name IN VARCHAR2) IS
  CURSOR c_local IS
    SELECT 'SITE3' site, product_id, product_name, price FROM product_frag3 WHERE LOWER(product_name) LIKE '%'||LOWER(p_name)||'%';
  v_row c_local%ROWTYPE;
BEGIN
  DBMS_OUTPUT.PUT_LINE('--- SITE3 RESULTS ---');
  OPEN c_local;
  LOOP
    FETCH c_local INTO v_row;
    EXIT WHEN c_local%NOTFOUND;
    DBMS_OUTPUT.PUT_LINE('ID:'||v_row.product_id||' NAME:'||v_row.product_name||' PRICE:'||v_row.price);
  END LOOP;
  CLOSE c_local;
END;
/

-- 10. Triggers: calculate cost and remote update (commented remote part)
CREATE OR REPLACE TRIGGER trg_calc_order_cost_ins3
BEFORE INSERT ON orders_frag3
FOR EACH ROW
DECLARE
  v_price NUMBER;
BEGIN
  IF :NEW.product_price IS NULL THEN
    SELECT price INTO v_price FROM product_frag3 WHERE product_id = :NEW.product_id;
    :NEW.product_price := v_price;
  ELSE
    v_price := :NEW.product_price;
  END IF;

  IF :NEW.total_cost IS NULL THEN
    :NEW.total_cost := v_price * NVL(:NEW.quantity,1);
  END IF;

  -- update local customer
  UPDATE customer_local SET total_payment = NVL(total_payment,0) + :NEW.total_cost WHERE customer_id = :NEW.customer_id;
  IF SQL%ROWCOUNT = 0 THEN
    INSERT INTO customer_local(customer_id, customer_name, total_payment) VALUES(:NEW.customer_id, NULL, :NEW.total_cost);
  END IF;

END;
/

CREATE OR REPLACE TRIGGER trg_update_total_payment_delete3
BEFORE DELETE ON orders_frag3
FOR EACH ROW
BEGIN
  UPDATE customer_local SET total_payment = NVL(total_payment,0) - NVL(:OLD.total_cost,0) WHERE customer_id = :OLD.customer_id;

END;
/

-- End of LINK_SON script
COMMIT;