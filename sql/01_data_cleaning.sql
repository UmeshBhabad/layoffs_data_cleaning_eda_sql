/* ==============================================================================
   Project  : Layoffs Data Cleaning and EDA using SQL
   File     : 01_data_cleaning.sql  (Phase 1 of 2)
   Database : MySQL 8.x  (schema: world_layoffs)
   Source   : data/raw/layoffs.csv, imported as the table `layoffs`
   Author   : Umesh Bhabad

   Purpose
   -------
   Turn the raw layoffs table into an analysis-ready table. The raw table is
   never modified. All changes are made on staging copies.

   Cleaning steps
   --------------
   Step 0. Create a staging copy of the raw table
   Step 1. Remove duplicate rows
   Step 2. Standardize the data (spaces, labels, country names, date type, column types)
   Step 3. Handle NULL and blank values
   Step 4. Remove unusable rows and helper columns

   How to run
   ----------
   1. Import data/raw/layoffs.csv into world_layoffs.layoffs
   2. Run this script one statement at a time, top to bottom
   3. Output table: layoffs_cleaned (input for 02_exploratory_data_analysis.sql)

   Conventions
   -----------
   - "Check:" marks a query that verifies the previous change
   - Commented-out code is kept on purpose to document an approach that failed
   ============================================================================== */

USE world_layoffs;

-- Preview the raw data
SELECT *
FROM world_layoffs.layoffs;


/* ------------------------------------------------------------------------------
   Step 0. Create a staging copy of the raw table
   Why: the raw table stays untouched, so any mistake can be undone by rebuilding
   the staging table.
   ------------------------------------------------------------------------------ */

-- Copy the structure (columns and data types) of the raw table
CREATE TABLE layoffs_staging
LIKE layoffs;

-- Check: the new table exists and is empty
SELECT *
FROM world_layoffs.layoffs_staging;

-- Copy all rows from the raw table
INSERT INTO layoffs_staging
SELECT *
FROM layoffs;

-- Row count: raw table vs staging copy (expected: both 2361)
SELECT 'raw (layoffs)' AS table_name, COUNT(*) AS total_rows
FROM layoffs
UNION ALL
SELECT 'staging (layoffs_staging)', COUNT(*)
FROM layoffs_staging;

/* ------------------------------------------------------------------------------
   Step 1. Remove duplicate rows
   Approach: number the rows inside each group of identical records with
   ROW_NUMBER(). Row number 1 is the original, anything above 1 is a duplicate.
   ------------------------------------------------------------------------------ */

-- 1a. Preview the row numbers.
-- PARTITION BY lists every column, so only fully identical rows share a group.
SELECT
	*,
	ROW_NUMBER() OVER(
		PARTITION BY company, location, industry, total_laid_off, percentage_laid_off, `date`, stage, country, funds_raised_millions) AS row_num
FROM world_layoffs.layoffs_staging;

-- 1b. List the duplicates (row_num > 1) using a CTE.
-- A window function cannot be filtered in WHERE directly, so the CTE wraps it.
WITH duplicate_cte AS
(
	SELECT
	*,
	ROW_NUMBER() OVER(
		PARTITION BY company, location, industry, total_laid_off, percentage_laid_off, `date`, stage, country, funds_raised_millions) AS row_num
	FROM world_layoffs.layoffs_staging
)
SELECT *
FROM duplicate_cte
WHERE row_num > 1;

-- Check: inspect two flagged companies to confirm they are real duplicates
SELECT *
FROM world_layoffs.layoffs_staging
WHERE company = 'oda';

SELECT *
FROM world_layoffs.layoffs_staging
WHERE company = 'casper';

-- 1c. Delete the duplicates.
-- Attempted first: deleting directly through the CTE.
-- Failed with "The target table duplicate_cte of the DELETE is not updatable",
-- because MySQL cannot delete from a CTE.

	-- WITH duplicate_cte AS
	-- (
	-- 	SELECT
	-- 	*,
	-- 	ROW_NUMBER() OVER(
	-- 		PARTITION BY company, location, industry, total_laid_off, percentage_laid_off, `date`, stage, country, funds_raised_millions) AS row_num
	-- 	FROM world_layoffs.layoffs_staging
	-- )
	-- DELETE
	-- FROM duplicate_cte
	-- WHERE row_num > 1;

-- Fix: create a second staging table that stores row_num as a real column,
-- then delete from that table.
CREATE TABLE `layoffs_staging2` (
  `company` text,
  `location` text,
  `industry` text,
  `total_laid_off` int DEFAULT NULL,
  `percentage_laid_off` text,
  `date` text,
  `stage` text,
  `country` text,
  `funds_raised_millions` int DEFAULT NULL,
  `row_num` INT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- Check: the new table exists and is empty
SELECT *
FROM world_layoffs.layoffs_staging2;

-- Load the rows together with their row numbers
INSERT INTO layoffs_staging2
SELECT
	*,
	ROW_NUMBER() OVER(
		PARTITION BY company, location, industry, total_laid_off, percentage_laid_off, `date`, stage, country, funds_raised_millions) AS row_num
FROM world_layoffs.layoffs_staging;

-- Row count: rows loaded and how many of them are duplicates (expected: 2361 and 5)
SELECT
	COUNT(*) AS rows_loaded,
	SUM(row_num > 1) AS duplicate_rows
FROM world_layoffs.layoffs_staging2;

-- Check: rows that are about to be deleted
SELECT *
FROM world_layoffs.layoffs_staging2
WHERE row_num > 1;

-- Delete the duplicate rows
DELETE
FROM world_layoffs.layoffs_staging2
WHERE row_num > 1;

-- Check: no duplicates remain (expected: 0 rows)
SELECT *
FROM world_layoffs.layoffs_staging2
WHERE row_num > 1;

-- Row count after removing duplicates (expected: 2356)
SELECT COUNT(*) AS rows_after_dedup
FROM world_layoffs.layoffs_staging2;

/* ------------------------------------------------------------------------------
   Step 2. Standardize the data
   Goal: make equal values look equal, so grouping and filtering work correctly.
   ------------------------------------------------------------------------------ */

-- 2a. Trim leading and trailing spaces from company names

-- Preview: compare the original value with the trimmed value
SELECT company, TRIM(company)
FROM world_layoffs.layoffs_staging2;

UPDATE layoffs_staging2
SET company = TRIM(company);

-- Check: both columns should now match
SELECT company, TRIM(company)
FROM world_layoffs.layoffs_staging2;

-- 2b. Merge industry label variations (for example 'Crypto' and 'Crypto Currency')

-- Preview: list every distinct industry and look for near-duplicates
SELECT DISTINCT industry
FROM world_layoffs.layoffs_staging2
ORDER BY 1;

-- Preview: rows that match the Crypto pattern
SELECT *
FROM world_layoffs.layoffs_staging2
WHERE industry LIKE 'Crypto%';

-- Rename every Crypto variant to a single label
UPDATE layoffs_staging2
SET industry = 'Crypto'
WHERE industry LIKE 'Crypto%';

-- Check: only one Crypto label should remain
SELECT *
FROM world_layoffs.layoffs_staging2
WHERE industry LIKE 'Crypto%';

SELECT DISTINCT industry
FROM world_layoffs.layoffs_staging2;

SELECT *
FROM world_layoffs.layoffs_staging2;

-- 2c. Remove the trailing period from country names
-- ('United States' and 'United States.' are the same country)

-- Preview: list every distinct country and look for variations
SELECT DISTINCT country
FROM world_layoffs.layoffs_staging2
ORDER BY 1;

SELECT *
FROM world_layoffs.layoffs_staging2
WHERE country LIKE 'United States%'
ORDER BY 1;

-- Preview: original value next to the corrected value
SELECT DISTINCT country, TRIM(TRAILING '.' FROM country)
FROM world_layoffs.layoffs_staging2
ORDER BY 1;

UPDATE layoffs_staging2
SET country = TRIM(TRAILING '.' FROM country)
WHERE country LIKE 'United States%';

-- Check: the variation should be gone
SELECT DISTINCT country, TRIM(TRAILING '.' FROM country)
FROM world_layoffs.layoffs_staging2
ORDER BY 1;

-- 2d. Convert the date column from text (m/d/yyyy) to the DATE data type

-- Preview: current text value next to the converted value
SELECT `date`
FROM layoffs_staging2;

SELECT `date`,
STR_TO_DATE(`date`, '%m/%d/%Y')
FROM layoffs_staging2;

-- Rewrite the values in the standard YYYY-MM-DD format
UPDATE layoffs_staging2
SET date = STR_TO_DATE(`date`, '%m/%d/%Y');

SELECT *
FROM layoffs_staging2;

-- Change the column type. This must come after the UPDATE: MySQL can only
-- convert text to DATE once the values are already in YYYY-MM-DD format.
ALTER TABLE layoffs_staging2
MODIFY COLUMN `date` DATE;

-- 2e. Convert percentage_laid_off from text to DECIMAL(5,4)

SELECT *
FROM layoffs_staging2
WHERE percentage_laid_off IS NULL;

-- Check: no non-numeric values (expected: 0 rows)
SELECT DISTINCT percentage_laid_off
FROM layoffs_staging2
WHERE percentage_laid_off NOT REGEXP '^[0-9]*\\.?[0-9]+$';

-- Check: conversion loses no precision (expected: 0 rows)

SELECT
	percentage_laid_off
FROM layoffs_staging2
WHERE percentage_laid_off IS NOT NULL
AND CAST(percentage_laid_off AS DECIMAL(5,4)) <> percentage_laid_off;

-- Change the column type.

ALTER TABLE layoffs_staging2
MODIFY COLUMN percentage_laid_off DECIMAL(5, 4);

SELECT count(percentage_laid_off)
FROM layoffs_staging2;

/* ------------------------------------------------------------------------------
   Step 3. Handle NULL and blank values
   Goal: fill gaps where another row of the same company holds the answer,
   and remove rows that cannot be filled.
   ------------------------------------------------------------------------------ */

-- 3a. Review where the NULLs are
SELECT *
FROM layoffs_staging2
WHERE total_laid_off IS NULL;

SELECT *
FROM layoffs_staging2
WHERE percentage_laid_off IS NULL;

-- Rows with neither layoff figure (these are removed in Step 4)
SELECT *
FROM layoffs_staging2
WHERE total_laid_off IS NULL
AND percentage_laid_off IS NULL;

-- Rows with a missing or blank industry
SELECT *
FROM layoffs_staging2
WHERE industry IS NULL
OR industry = '';

-- 3b. Populate missing industry values from other rows of the same company

-- Example: Airbnb has one row with a blank industry and other rows with 'Travel'
SELECT *
FROM layoffs_staging2
WHERE company = 'Airbnb';

-- Convert blank strings to NULL first, so later filters only need IS NULL
UPDATE layoffs_staging2
SET industry = NULL
WHERE industry = '';

-- Preview: t1 is the row with the gap, t2 is a row of the same company and
-- location that has the value
SELECT
	t1.industry,
    t2.industry
FROM layoffs_staging2 t1
JOIN layoffs_staging2 t2
	ON t1.company = t2.company
    AND t1.location = t2.location
WHERE (t1.industry IS NULL OR t1.industry = '')
AND t2.industry IS NOT NULL;

-- Fill the gaps with the matching industry (self join)

UPDATE layoffs_staging2 t1
JOIN layoffs_staging2 t2
	ON t1.company = t2.company
    AND t1.location = t2.location
SET t1.industry = t2.industry
WHERE (t1.industry IS NULL)
AND t2.industry IS NOT NULL;

-- Check: no more fillable gaps (expected: 0 rows)
SELECT
	t1.industry,
    t2.industry
FROM layoffs_staging2 t1
JOIN layoffs_staging2 t2
	ON t1.company = t2.company
    AND t1.location = t2.location
WHERE (t1.industry IS NULL OR t1.industry = '')
AND t2.industry IS NOT NULL;

-- Check: Airbnb is now filled
SELECT *
FROM layoffs_staging2
WHERE company = 'Airbnb';

-- Check: remaining NULL industries (cannot be filled, no other row to copy from)
SELECT *
FROM layoffs_staging2
WHERE industry IS NULL
OR industry = '';

-- Example: Bally's Interactive has only one row, so its industry stays NULL
SELECT *
FROM layoffs_staging2
WHERE company LIKE 'Bally%';

SELECT *
FROM layoffs_staging2;


/* ------------------------------------------------------------------------------
   Step 4. Remove unusable rows and helper columns
   ------------------------------------------------------------------------------ */

-- 4a. Delete rows with no layoff data.
-- A layoff record with neither total_laid_off nor percentage_laid_off cannot
-- support the analysis, and there is no reliable way to estimate the values.

-- Preview: rows to be deleted
SELECT *
FROM layoffs_staging2
WHERE total_laid_off IS NULL
AND percentage_laid_off IS NULL;

DELETE
FROM layoffs_staging2
WHERE total_laid_off IS NULL
AND percentage_laid_off IS NULL;

-- Check: no such rows remain (expected: 0 rows)
SELECT *
FROM layoffs_staging2
WHERE total_laid_off IS NULL
AND percentage_laid_off IS NULL;

-- Row count of the final cleaned table (expected: 1995)
SELECT COUNT(*) AS rows_after_cleaning
FROM layoffs_staging2;

-- 4b. Drop the helper column that was only needed to find duplicates
SELECT *
FROM layoffs_staging2;

ALTER TABLE layoffs_staging2
DROP COLUMN row_num;

-- Rename table layoffs_staging2 to layoffs_cleaned

RENAME TABLE layoffs_staging2 TO layoffs_cleaned;

-- Final result: the cleaned table used by the EDA script
SELECT *
FROM layoffs_cleaned;
