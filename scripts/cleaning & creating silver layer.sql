/*
===============================================================================
 Data Cleaning Script
===============================================================================
 Purpose:
   Quality checks and cleaning queries for the raw tables below.
   For each table: (1) run the CHECK queries, (2) apply the CLEAN query.

 Tables covered:
   1. cust_info      (CRM customers)
   2. prd_info       (CRM products)
   3. sales_details  (CRM sales)
   4. CUST_AZ12      (ERP customers)

 Rule of thumb:
   Every check query should return NO rows. If it returns rows,
   the data has an issue that the clean query must fix.
===============================================================================
*/


/* ===========================================================================
   1. cust_info
   =========================================================================== */

-- ---------------------------------------------------------------------------
-- CHECK 1.1: Primary key must have no NULLs and no duplicates
-- Expectation: no results
-- ---------------------------------------------------------------------------
SELECT
    cst_id,
    COUNT(*) AS cnt
FROM cust_info
GROUP BY cst_id
HAVING COUNT(*) > 1
    OR cst_id IS NULL;


-- ---------------------------------------------------------------------------
-- FIX 1.1: Keep only the most recent record per customer
-- (removes duplicates and NULL ids)
-- ---------------------------------------------------------------------------
SELECT *
FROM (
    SELECT
        *,
        ROW_NUMBER() OVER (
            PARTITION BY cst_id
            ORDER BY cst_create_date DESC
        ) AS flag_last
    FROM cust_info
    WHERE cst_id IS NOT NULL
) t
WHERE flag_last = 1;


-- ---------------------------------------------------------------------------
-- CHECK 1.2: Unwanted spaces in text columns
-- Expectation: no results
-- Fix: wrap the column in TRIM()
-- ---------------------------------------------------------------------------
SELECT cst_firstname
FROM cust_info
WHERE cst_firstname != TRIM(cst_firstname);


-- ---------------------------------------------------------------------------
-- CHECK 1.3: Data standardization and consistency
-- Inspect the distinct values (expected: M, F, NULL), then map them
-- to full names with CASE WHEN.
-- ---------------------------------------------------------------------------
SELECT DISTINCT cst_gndr
FROM cust_info;


-- ---------------------------------------------------------------------------
-- CLEAN 1: Final cust_info query
-- ---------------------------------------------------------------------------
SELECT
    cst_id,
    cst_key,
    TRIM(cst_firstname) AS cst_firstname,
    TRIM(cst_lastname)  AS cst_lastname,

    CASE UPPER(TRIM(cst_marital_status))
        WHEN 'M' THEN 'Married'
        WHEN 'S' THEN 'Single'
        ELSE 'n/a'
    END AS cst_marital_status,

    CASE UPPER(TRIM(cst_gndr))
        WHEN 'M' THEN 'Male'
        WHEN 'F' THEN 'Female'
        ELSE 'n/a'
    END AS cst_gndr,

    cst_create_date
FROM (
    SELECT
        *,
        ROW_NUMBER() OVER (
            PARTITION BY cst_id
            ORDER BY cst_create_date DESC
        ) AS flag_last
    FROM cust_info
    WHERE cst_id IS NOT NULL
) t
WHERE flag_last = 1;

-- Tip: SUBSTRING() cuts a long string into parts,
--      REPLACE() swaps one value for another.


/* ===========================================================================
   2. prd_info
   =========================================================================== */

-- ---------------------------------------------------------------------------
-- CHECK 2.1: Numeric columns (cost, price, ...) must not be NULL or negative
-- Expectation: no results
-- Fix: replace NULL with 0 (COALESCE)
-- ---------------------------------------------------------------------------
SELECT prd_cost
FROM prd_info
WHERE prd_cost < 0
   OR prd_cost IS NULL;


-- ---------------------------------------------------------------------------
-- CHECK 2.2: Date order. The end date must not be earlier than the start date
-- Expectation: no results
-- Fix: keep the start date, and derive the end date from the NEXT record's
--      start date minus one day using LEAD().
-- ---------------------------------------------------------------------------
SELECT
    prd_start_dt,
    prd_end_dt
FROM prd_info
WHERE prd_end_dt < prd_start_dt;


-- ---------------------------------------------------------------------------
-- CLEAN 2: Final prd_info query
-- ---------------------------------------------------------------------------
SELECT
    prd_id,
    REPLACE(SUBSTRING(prd_key, 1, 5), '-', '_')  AS cat_id,
    SUBSTRING(prd_key, 7, LENGTH(prd_key))       AS prd_key,
    prd_nm,
    COALESCE(prd_cost, 0)                        AS prd_cost,

    CASE UPPER(TRIM(prd_line))
        WHEN 'M' THEN 'Mountain'
        WHEN 'R' THEN 'Road'
        WHEN 'S' THEN 'Other Sales'
        WHEN 'T' THEN 'Touring'
        ELSE 'n/a'
    END AS prd_line,

    prd_start_dt,
    LEAD(prd_start_dt) OVER (
        PARTITION BY prd_key
        ORDER BY prd_start_dt
    ) - 1 AS prd_end_dt
FROM prd_info;


/* ===========================================================================
   3. sales_details
   =========================================================================== */

-- ---------------------------------------------------------------------------
-- CHECK 3.1: Date order. Order date must not come after ship or due date
-- Expectation: no results
-- (Other date columns: check that values are not <= 0)
-- ---------------------------------------------------------------------------
SELECT
    sls_order_dt,
    sls_ship_dt,
    sls_due_dt
FROM sales_details
WHERE sls_order_dt > sls_ship_dt
   OR sls_order_dt > sls_due_dt;


-- ---------------------------------------------------------------------------
-- CHECK 3.2: Sales = Quantity * Price, with no NULLs, zeros or negatives
-- Expectation: no results
-- ---------------------------------------------------------------------------
SELECT DISTINCT
    sls_sales,
    sls_quantity,
    sls_price
FROM sales_details
WHERE sls_sales != sls_quantity * sls_price
   OR sls_sales    IS NULL
   OR sls_quantity IS NULL
   OR sls_price    IS NULL
   OR sls_sales    <= 0
   OR sls_quantity <= 0
   OR sls_price    <= 0
ORDER BY sls_sales, sls_quantity, sls_price;


-- ---------------------------------------------------------------------------
-- CLEAN 3: Final sales_details query
--   * Dates stored as integers (YYYYMMDD) are converted to real DATEs;
--     invalid values become NULL.
--   * Bad sales values are recalculated as quantity * ABS(price).
--   * Bad price values are recalculated as sales / quantity.
-- ---------------------------------------------------------------------------
SELECT
    sls_ord_num,
    sls_prd_key,
    sls_cust_id,

    CASE
        WHEN sls_order_dt = 0 OR LENGTH(CAST(sls_order_dt AS VARCHAR)) != 8 THEN NULL
        ELSE STRPTIME(CAST(sls_order_dt AS VARCHAR), '%Y%m%d')::DATE
    END AS sls_order_dt,

    CASE
        WHEN sls_ship_dt = 0 OR LENGTH(CAST(sls_ship_dt AS VARCHAR)) != 8 THEN NULL
        ELSE STRPTIME(CAST(sls_ship_dt AS VARCHAR), '%Y%m%d')::DATE
    END AS sls_ship_dt,

    CASE
        WHEN sls_due_dt = 0 OR LENGTH(CAST(sls_due_dt AS VARCHAR)) != 8 THEN NULL
        ELSE STRPTIME(CAST(sls_due_dt AS VARCHAR), '%Y%m%d')::DATE
    END AS sls_due_dt,

    CASE
        WHEN sls_sales IS NULL
          OR sls_sales <= 0
          OR sls_sales != sls_quantity * ABS(sls_price)
        THEN sls_quantity * ABS(sls_price)   -- FIX: original returned a boolean
        ELSE sls_sales
    END AS sls_sales,

    sls_quantity,

    CASE
        WHEN sls_price IS NULL OR sls_price <= 0
        THEN sls_sales / NULLIF(sls_quantity, 0)
        ELSE sls_price
    END AS sls_price
FROM sales_details;


/* ===========================================================================
   4. ERP: CUST_AZ12
   =========================================================================== */

-- ---------------------------------------------------------------------------
-- CLEAN 4: Remove the 'NAS' prefix from customer ids
-- ---------------------------------------------------------------------------
SELECT
    CASE
        WHEN CID LIKE 'NAS%' THEN SUBSTRING(CID, 4, LENGTH(CID))
        ELSE CID
    END AS CID,
    BDATE,
    GEN
FROM CUST_AZ12;
