--Test Case 1: Đứng ở Site 3 mua hàng của Site 1 (Đây là trường hợp bạn gặp lỗi trước đó)

-- Chạy tại SITE 3 (SON)
BEGIN
    -- Mua Product ID 10 (của Site 1), Số lượng 2
    AddOrder(8001, 10, 201, 2, 'Site 3 mua hang Site 1');
END;
/
-- Kiểm tra: Select qua DB Link xem đơn hàng có ở Site 1 không
SELECT * FROM orders_frag1@LINK_TRUNG_DB WHERE orders_id = 8001;


--Test Case 2: Đứng ở Site 1 mua hàng của Site 2

SQL

-- Chạy tại SITE 1 (TRUNG)
BEGIN
    -- Mua Product ID 35 (của Site 2), Số lượng 5
    AddOrder(8002, 35, 201, 5, 'Site 1 mua hang Site 2');
END;
/
-- Kiểm tra: Select qua DB Link xem đơn hàng có ở Site 2 không
SELECT * FROM orders_frag2@LINK_TUAN_DB WHERE orders_id = 8002;