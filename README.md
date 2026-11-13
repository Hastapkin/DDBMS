# Distributed Product Management Database (Oracle)

Course project for Distributed Database Management Systems: a product and order database split across **three Oracle sites** that talk to each other through database links.

Team of three, one site per member. I designed the fragmentation scheme and wrote most of the implementation.

## Design

Global schema: `Product`, `Customer`, `Orders`, `Supplier`.

| Site | Holds |
|---|---|
| Site 1 | `product_frag1`, `orders_frag1` (product_id 1–29), local copy of `Customer`, `supplier_frag1`, `supplier_frag2` |
| Site 2 | `product_frag2`, `orders_frag2` (product_id 30–59), **master** `Customer`, `supplier_frag1` |
| Site 3 | `product_frag3`, `orders_frag3` (product_id 60–89), local copy of `Customer`, `supplier_frag1` |

- **Horizontal fragmentation**: `Product` and `Orders` are split by `product_id` range, so each site owns the orders for its own products.
- **Vertical fragmentation**: `Supplier` is split into `supplier_frag1` (id, name, location; on every site) and `supplier_frag2` (phone, contact person, address, email; Site 1 only).
- **Replication**: the `Customer` master lives at Site 2, with local copies at Sites 1 and 3.

## Logic (PL/SQL)

- `AddOrder` checks which site owns the product and, if it is not the local one, forwards the call over a database link (for example `AddOrder@LINK_TUAN`). An order placed at any site lands in the right fragment.
- `AddProduct`, `SearchProduct` and the function `countpriceproductinsite` work on the local fragment.
- Triggers compute an order's total cost on insert and keep the customer's `total_payment` in sync on insert and delete.
- Site 1 also has supplier management procedures (`Add_Supplier`, `Update_Supplier`, `Delete_Supplier`) and `CountTypeProduct`.

## Files

| File | Purpose |
|---|---|
| `PLSQL_Site1_TRUNG.sql`, `PLSQL_Site2_TUAN.sql`, `PLSQL_Site3_SON.sql` | Tables, functions, procedures and triggers for each site |
| `test_trung.sql`, `test_tuan.sql`, `test_son.sql` | Per-site tests |
| `test_cross_site.sql` | Cross-site tests: place an order at one site for a product owned by another, then check it over the link |
| `Final_Project.docx` | Project report |

## Running it

1. Run each site script on its own Oracle instance (or schema).
2. Create the database links between the sites. The link names used in the scripts are `LINK_TRUNG`, `LINK_TUAN` and `LINK_SON`; adjust them to your connection details.
3. Run the per-site tests, then `test_cross_site.sql`.
