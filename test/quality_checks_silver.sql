/*

===========================================================================
Quality Checks
===========================================================================

Script Purpose:
	Performs quality checks for data consistency, accuracy
	and standardization in the 'silver' schema. Includes checks for:
		- Null or duplicate primary keys
		- Unwanted spaces in string fields
		- Data standardization and consistency 
		- Invalid date ranges and orders
		- Data consistency across related tables

	Run these checks after data loading silver layer.
	Investigate and resolve any issues found during checks.

*/

--===========================================================
-- Table: silver.crm_cust_info
--===========================================================

-----------------------------------------------
-- Check for NULLs or duplicates in Primary Key
-- Expectation: No Results
-----------------------------------------------

SELECT
	cst_id,
	COUNT(*)
FROM silver.crm_cust_info
GROUP BY cst_id
HAVING COUNT(*) > 1 OR cst_id IS NULL;

----------------------------
-- Check for unwanted spaces
-- Expectation: No Results
----------------------------

SELECT
	cst_firstname
FROM silver.crm_cust_info
WHERE cst_firstname != TRIM(cst_firstname);

SELECT
	cst_lastname
FROM silver.crm_cust_info
WHERE cst_lastname != TRIM(cst_lastname);

SELECT
	cst_gndr
FROM silver.crm_cust_info
WHERE cst_gndr != TRIM(cst_gndr);

----------------------------------------------
-- Data Standardization and Consistency Checks
----------------------------------------------

SELECT DISTINCT cst_gndr
FROM silver.crm_cust_info;

SELECT DISTINCT cst_marital_status
FROM silver.crm_cust_info;

--===========================================================
-- Table: silver.crm_prd_info
--===========================================================

-----------------------------------------------
-- Check for NULLs or duplicates in Primary Key
-- Expectation: No Results
-----------------------------------------------

SELECT
	prd_id,
	COUNT(*)
FROM silver.crm_prd_info
GROUP BY prd_id
HAVING COUNT(*) > 1 OR prd_id IS NULL;

----------------------------
-- Check for unwanted spaces
-- Expectation: No Results
----------------------------

SELECT 
	prd_nm
FROM silver.crm_prd_info
WHERE prd_nm != TRIM(prd_nm);

-------------------------------------
-- Check for NULL or Negative Numbers
-- Expectation: No Results
-------------------------------------

SELECT 
	prd_cost
FROM silver.crm_prd_info
WHERE prd_cost < 0 OR prd_cost IS NULL;


----------------------------------------------
-- Data Standardization and Consistency Checks
----------------------------------------------

SELECT DISTINCT prd_line
FROM silver.crm_prd_info;

--------------------------------
-- Check for Invalid Date Orders
--------------------------------

SELECT
	*
FROM silver.crm_prd_info
WHERE prd_end_dt < prd_start_dt;

--===========================================================
-- Table: silver.crm_sales_details
--===========================================================

----------------------------
-- Check for unwanted spaces
-- Expectation: No Results
----------------------------

-- Check 'sls_ord_num'
SELECT 
	*
FROM silver.crm_sales_details
WHERE sls_ord_num != TRIM(sls_ord_num);

-- Check 'sls_prd_key'
SELECT 
	*
FROM silver.crm_sales_details
WHERE sls_prd_key != TRIM(sls_prd_key);

------------------------------------------------------------
-- Check for key values that do not exist in related tables
-- Key values from silver.crm_sales_details used to join other tables: 
--	1: 'sls_prd_key' ---> 'prd_key' in 'silver.crm_prd_info'
--	2: 'sls_cust_id' ---> 'cst_id'  in 'silver.crm_cust_info'
-- Expectation: No Results
------------------------------------------------------------

-- Check 'sls_prd_key' 
SELECT *
FROM silver.crm_sales_details
WHERE sls_prd_key NOT IN (
	SELECT prd_key FROM silver.crm_prd_info)

-- Check 'sls_cust_id' 
SELECT *
FROM silver.crm_sales_details
WHERE sls_cust_id NOT IN (
	SELECT cst_id FROM silver.crm_cust_info)

--------------------------
-- Check for Invalid Dates
--------------------------

SELECT
	NULLIF(sls_order_dt, 0) AS sls_order_dt
FROM silver.crm_sales_details
WHERE sls_order_dt <= 0 
	  OR LEN(sls_order_dt) != 8
	  OR sls_order_dt > 20500101
	  OR sls_order_dt < 19000101;

SELECT
	NULLIF(sls_ship_dt, 0) AS sls_ship_dt
FROM silver.crm_sales_details
WHERE sls_ship_dt <= 0 
	  OR LEN(sls_ship_dt) != 8
	  OR sls_ship_dt > 20500101
	  OR sls_ship_dt < 19000101;

SELECT
	NULLIF(sls_due_dt, 0) AS sls_due_dt
FROM silver.crm_sales_details
WHERE sls_due_dt <= 0 
	  OR LEN(sls_due_dt) != 8
	  OR sls_due_dt > 20500101
	  OR sls_due_dt < 19000101;

-- Invalid Date Orders

SELECT
	*
FROM silver.crm_sales_details
WHERE sls_order_dt > sls_ship_dt OR sls_order_dt > sls_due_dt;

-------------------------------------------------------------
-- Check Data Consistency: Between Sales, Quantity, and Price
-- >> Sales = Quantity * Price
-- >> Values must not be NULL, zero or negativ
-------------------------------------------------------------

SELECT DISTINCT
	sls_sales AS old_sls_sales,
	sls_quantity,
	sls_price AS old_sls_price,
	CASE 
		WHEN sls_sales IS NULL OR sls_sales <= 0 OR sls_sales != sls_quantity * ABS(sls_price)
			THEN sls_quantity * sls_price
		ELSE sls_sales
	END AS sls_sales,
	CASE	
		WHEN sls_price IS NULL OR sls_price <= 0
			THEN sls_sales / NULLIF(sls_quantity, 0)
		ELSE sls_price
	END AS sls_price
FROM silver.crm_sales_details
WHERE sls_sales != sls_quantity * sls_price
	  OR sls_sales IS NULL OR sls_quantity IS NULL OR sls_price IS NULL
	  OR sls_sales <= 0 OR sls_quantity <= 0 OR sls_price <= 0
ORDER BY sls_sales, sls_quantity, sls_price;

--===========================================================
-- Table: silver.erp_cust_az12
--===========================================================

-- Table 'silver.crm_cust_info' is used to Join on 'cst_key'

-------------------------------------------------
-- Check Data Consistency between Joinable Tables 
-------------------------------------------------

-- Remove 'NAS' prefix from 'cid' in 'bronze.erp_cust_az12' to match 'cst_id' in 'silver.crm_cust_info'
SELECT
	cid,
	CASE 
		WHEN cid LIKE 'NAS%' THEN SUBSTRING(cid, 4, LEN(cid)) -- Remove 'NAS' prefix if present
		ELSE cid
	END AS cid,
	bdate,
	gen
FROM silver.erp_cust_az12;

-- Check for 'cid' values in 'silver.erp_cust_az12' that do not exist in 'cst_id' of 'silver.crm_cust_info'
-- After transforming 
SELECT
	cid,
	CASE 
		WHEN cid LIKE 'NAS%' THEN SUBSTRING(cid, 4, LEN(cid))
		ELSE cid
	END AS cid,
	bdate,
	gen
FROM silver.erp_cust_az12
WHERE 	
	CASE 
		WHEN cid LIKE 'NAS%' THEN SUBSTRING(cid, 4, LEN(cid))
		ELSE cid
	END NOT IN (
		SELECT DISTINCT cst_key FROM silver.crm_cust_info)

------------------------------------
-- Check for Invalid Dates in 'bdate'
------------------------------------

-- Check for VERY old customers or customers with birthdates in the future
SELECT 
	bdate
FROM silver.erp_cust_az12 
WHERE bdate < '1924-01-01' OR bdate > GETDATE();

---------------------------------------
-- Data Standardization and Consistency 
---------------------------------------

SELECT DISTINCT 
	gen,
	CASE 
		WHEN UPPER(TRIM(gen)) IN ('F', 'FEMALE') THEN 'Female'
		WHEN UPPER(TRIM(gen)) IN ('M', 'MALE') THEN 'Male'
		ELSE 'N/A'
	END AS gen2
FROM silver.erp_cust_az12;

--===========================================================
-- Table: silver.erp_loc_a101
--===========================================================

-- Table 'silver.crm_cust_info' is used to Join on 'cst_key'

-------------------------------------------------
-- Check Data Consistency between Joinable Tables 
-------------------------------------------------

-- Column 'cid' in 'bronze.erp_loc_a101' should match 'cst_key' in 'silver.crm_cust_info' for joinability
-- Remove '-' in cid to match with 'cst_key' in 'silver.crm_cust_info'
SELECT
	cid,
	REPLACE(cid, '-', '') AS cid,
	cntry
FROM silver.erp_loc_a101

SELECT
	*
FROM silver.crm_cust_info;

---------------------------------------
-- Data Standardization and Consistency
---------------------------------------

SELECT DISTINCT
	cntry
FROM silver.erp_loc_a101
ORDER BY cntry;

SELECT DISTINCT
	CASE 
		WHEN TRIM(cntry) = 'DE' THEN 'Germany'
		WHEN TRIM(cntry) IN ('US', 'USA') THEN 'United States'
		WHEN TRIM(cntry) = '' OR cntry IS NULL THEN 'N/A'
		ELSE TRIM(cntry)
	END AS cntry
FROM silver.erp_loc_a101

--===========================================================
-- Table: silver.erp_px_cat_g1v2
--===========================================================

-- Table 'silver.crm_prd_info' is used to Join on 'prd_key'

-------------------------------------------------
-- Check Data Consistency between Joinable Tables 
-------------------------------------------------

-- Column 'id' in 'silver.erp_px_cat_g1v2' should match 'cat_id' in 'silver.crm_prd_info' for joinability
-- Already done in Quality Check in 'silver.crm_prd_info' transform

----------------------------
-- Check for unwanted spaces
----------------------------

SELECT
	*
FROM silver.erp_px_cat_g1v2
WHERE cat != TRIM(cat);

SELECT
	*
FROM silver.erp_px_cat_g1v2
WHERE subcat != TRIM(subcat);

SELECT
	*
FROM silver.erp_px_cat_g1v2
WHERE maintenance != TRIM(maintenance);

--------------------------------------
-- Data Standarization and Consistency
--------------------------------------

SELECT DISTINCT
	cat
FROM silver.erp_px_cat_g1v2;

SELECT DISTINCT
	subcat
FROM silver.erp_px_cat_g1v2;

SELECT DISTINCT
	maintenance
FROM silver.erp_px_cat_g1v2;
