/*
===============================================================================
 Data Model Script (Star Schema)
===============================================================================
 Purpose:
   Combine the cleaned tables into business-ready objects:

     1. dim_customer : customer details from 3 cleaned tables
     2. dim_product  : current product details with category info
     3. fact_sales   : sales transactions linked to both dimensions

 Source tables (already cleaned):
   clean_cust_info, clean_CUST_AZ12, clean_LOC_A101,
   clean_prd_info, clean_PX_CAT_G1V2, clean_sales_details

 Rule of thumb:
   Every check query should return NO rows.
===============================================================================
*/


/* ===========================================================================
   1. dim_customer
   =========================================================================== */

-- ---------------------------------------------------------------------------
-- STEP 1.1: Join the 3 customer-related tables
-- ---------------------------------------------------------------------------
SELECT
    ci.cst_id,
    ci.cst_key,
    ci.cst_firstname,
    ci.cst_lastname,
    ci.cst_marital_status,
    ci.cst_gndr,
    ci.cst_create_date,
    ca.BDATE,
    ca.GEN,
    la.CNTRY
FROM clean_cust_info ci
LEFT JOIN clean_CUST_AZ12 ca
    ON ci.cst_key = ca.CID
LEFT JOIN clean_LOC_A101 la
    ON ci.cst_key = la.CID;


-- ---------------------------------------------------------------------------
-- CHECK 1.1: Primary key uniqueness after the joins
-- Expectation: no results (joins must not create duplicate customers)
-- ---------------------------------------------------------------------------
SELECT
    cst_id,
    COUNT(*) AS cnt
FROM (
    SELECT
        ci.cst_id,
        ci.cst_key,
        ci.cst_firstname,
        ci.cst_lastname,
        ci.cst_marital_status,
        ci.cst_gndr,
        ci.cst_create_date,
        ca.BDATE,
        ca.GEN,
        la.CNTRY
    FROM clean_cust_info ci
    LEFT JOIN clean_CUST_AZ12 ca
        ON ci.cst_key = ca.CID
    LEFT JOIN clean_LOC_A101 la
        ON ci.cst_key = la.CID
) t
GROUP BY cst_id
HAVING COUNT(*) > 1;


-- ---------------------------------------------------------------------------
-- CHECK 1.2: Data integrity. Gender exists in two tables (CRM and ERP).
-- Rule: CRM is the master source; use ERP only when CRM is 'n/a'.
-- Review the distinct combinations to confirm the logic works.
-- ---------------------------------------------------------------------------
SELECT DISTINCT
    ci.cst_gndr,
    ca.GEN,
    CASE
        WHEN ci.cst_gndr != 'n/a' THEN ci.cst_gndr
        ELSE COALESCE(ca.GEN, 'n/a')
    END AS new_gen
FROM clean_cust_info ci
LEFT JOIN clean_CUST_AZ12 ca
    ON ci.cst_key = ca.CID
ORDER BY 1, 2;


-- ---------------------------------------------------------------------------
-- FINAL 1: dim_customer
--   * Friendly column names
--   * Surrogate key (customer_key) generated with ROW_NUMBER()
-- ---------------------------------------------------------------------------
CREATE OR REPLACE VIEW dim_customer AS
SELECT
    ROW_NUMBER() OVER (ORDER BY ci.cst_id) AS customer_key,   -- surrogate key
    ci.cst_id                              AS customer_id,
    ci.cst_key                             AS customer_number,
    ci.cst_firstname                       AS first_name,
    ci.cst_lastname                        AS last_name,
    la.CNTRY                               AS country,
    ci.cst_marital_status                  AS marital_status,
    CASE
        WHEN ci.cst_gndr != 'n/a' THEN ci.cst_gndr
        ELSE COALESCE(ca.GEN, 'n/a')
    END                                    AS gender,
    ca.BDATE                               AS birth_date,
    ci.cst_create_date                     AS create_date
FROM clean_cust_info ci
LEFT JOIN clean_CUST_AZ12 ca
    ON ci.cst_key = ca.CID
LEFT JOIN clean_LOC_A101 la
    ON ci.cst_key = la.CID;


/* ===========================================================================
   2. dim_product
   =========================================================================== */

-- ---------------------------------------------------------------------------
-- STEP 2.1: Join product info with category info
-- Only current products are kept (end date IS NULL removes history)
-- ---------------------------------------------------------------------------
SELECT
    pn.prd_id,
    pn.cat_id,
    pn.prd_key,
    pn.prd_nm,
    pn.prd_cost,
    pn.prd_line,
    pn.prd_start_dt,
    pc.CAT,
    pc.SUBCAT,
    pc.MAINTENANCE
FROM clean_prd_info pn
LEFT JOIN clean_PX_CAT_G1V2 pc
    ON pn.cat_id = pc.ID
WHERE pn.prd_end_dt IS NULL;


-- ---------------------------------------------------------------------------
-- CHECK 2.1: Primary key uniqueness after the join
-- Expectation: no results
-- ---------------------------------------------------------------------------
SELECT
    prd_id,
    COUNT(*) AS cnt
FROM (
    SELECT
        pn.prd_id,
        pn.cat_id,
        pn.prd_key,
        pn.prd_nm,
        pn.prd_cost,
        pn.prd_line,
        pn.prd_start_dt,
        pc.CAT,
        pc.SUBCAT,
        pc.MAINTENANCE
    FROM clean_prd_info pn
    LEFT JOIN clean_PX_CAT_G1V2 pc
        ON pn.cat_id = pc.ID
    WHERE pn.prd_end_dt IS NULL
) t
GROUP BY prd_id
HAVING COUNT(*) > 1;


-- ---------------------------------------------------------------------------
-- FINAL 2: dim_product
--   * Friendly column names
--   * Surrogate key (product_key) generated with ROW_NUMBER()
--   * The original business key is renamed product_number so the two
--     keys no longer share the same name
-- ---------------------------------------------------------------------------
CREATE OR REPLACE VIEW dim_product AS
SELECT
    ROW_NUMBER() OVER (ORDER BY pn.prd_start_dt, pn.prd_key) AS product_key,  -- surrogate key
    pn.prd_id       AS product_id,
    pn.prd_key      AS product_number,
    pn.prd_nm       AS product_name,
    pn.cat_id       AS category_id,
    pc.CAT          AS category,
    pc.SUBCAT       AS subcategory,
    pc.MAINTENANCE  AS maintenance,
    pn.prd_cost     AS cost,
    pn.prd_line     AS product_line,
    pn.prd_start_dt AS start_date
FROM clean_prd_info pn
LEFT JOIN clean_PX_CAT_G1V2 pc
    ON pn.cat_id = pc.ID
WHERE pn.prd_end_dt IS NULL;   -- keep current products only (removes history)


/* ===========================================================================
   3. fact_sales
   =========================================================================== */

-- ---------------------------------------------------------------------------
-- FINAL 3: fact_sales
--   Sales transactions joined to both dimensions.
--   The fact table stores the dimensions' SURROGATE keys
--   (product_key, customer_key) instead of the business ids.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE VIEW fact_sales AS
SELECT
    sd.sls_ord_num   AS order_number,
    dp.product_key   AS product_key,
    dc.customer_key  AS customer_key,
    sd.sls_order_dt  AS order_date,
    sd.sls_ship_dt   AS shipping_date,
    sd.sls_due_dt    AS due_date,
    sd.sls_sales     AS sales,
    sd.sls_quantity  AS quantity,
    sd.sls_price     AS price
FROM clean_sales_details sd
LEFT JOIN dim_product dp
    ON sd.sls_prd_key = dp.product_number
LEFT JOIN dim_customer dc
    ON sd.sls_cust_id = dc.customer_id;


-- ---------------------------------------------------------------------------
-- CHECK 3.1: Referential integrity. Every sale should match a product
-- and a customer.
-- Expectation: no results
-- ---------------------------------------------------------------------------
SELECT *
FROM fact_sales
WHERE product_key IS NULL
   OR customer_key IS NULL;
