/* ==============================================================================
   Project  : Layoffs Data Cleaning and EDA using SQL
   File     : 02_exploratory_data_analysis.sql  (Phase 2 of 2)
   Database : MySQL 8.x  (schema: world_layoffs)
   Input    : layoffs_cleaned (output of 01_data_cleaning.sql)
   Author   : Umesh Bhabad

   Purpose
   -------
   Explore the cleaned layoffs data to find which companies, industries,
   countries, funding stages and time periods were hit hardest.

   Sections
   --------
   1. Overview: extremes and period covered
   2. Layoffs by industry, country, year and funding stage
   3. Layoff severity by company (average percentage)
   4. Progression over time: monthly totals and rolling total
   5. Company rankings: totals per year and top 5 per year

   Reading the results
   -------------------
   - total_laid_off is NULL in 378 of the 1,995 rows, so every SUM() below only
     counts events with a known headcount. Totals are a lower bound.
   - percentage_laid_off is a fraction (1 = 100% of the workforce).
   - Sorting by column position (ORDER BY 2) sorts by the second selected column.
   - NULL totals sort last when ordering from high to low.

   How to run
   ----------
   Run 01_data_cleaning.sql first, then run this script one statement at a time.
   ============================================================================== */

USE world_layoffs;

-- Preview the cleaned table

SELECT *
FROM layoffs_cleaned;


/* ------------------------------------------------------------------------------
   Section 1. Overview: extremes and period covered
   ------------------------------------------------------------------------------ */

-- 1a. Largest single layoff event and highest layoff percentage

SELECT
	MAX(total_laid_off),
    MAX(percentage_laid_off)
FROM layoffs_cleaned;

-- 1b. Companies that laid off 100% of their workforce (percentage_laid_off = 1)
-- Sorted by headcount: which fully closed companies were the largest?

SELECT *
FROM layoffs_cleaned
WHERE percentage_laid_off = 1
ORDER BY total_laid_off DESC;

-- Sorted by funding: which fully closed companies had raised the most money?

SELECT *
FROM layoffs_cleaned
WHERE percentage_laid_off = 1
ORDER BY funds_raised_millions DESC;

-- 1c. Companies with the most employees laid off in total

SELECT
	company,
    SUM(total_laid_off) AS total_laid_off
FROM layoffs_cleaned
GROUP BY company
ORDER BY 2 DESC;

-- 1d. Period covered by the dataset (first and last layoff date)

SELECT
	MIN(`date`),
    MAX(`date`)
FROM layoffs_cleaned;


/* ------------------------------------------------------------------------------
   Section 2. Layoffs by industry, country, year and funding stage
   Pattern: GROUP BY one category, SUM the headcount, sort high to low.
   ------------------------------------------------------------------------------ */

-- 2a. Total laid off by industry

SELECT
	industry,
    SUM(total_laid_off) AS total_laid_off
FROM layoffs_cleaned
GROUP BY industry
ORDER BY 2 DESC;

-- Preview: the table again, as a reference for the breakdowns that follow

SELECT *
FROM layoffs_cleaned;

-- 2b. Total laid off by country

SELECT
	country,
    SUM(total_laid_off) AS total_laid_off
FROM layoffs_cleaned
GROUP BY country
ORDER BY 2 DESC;

-- 2c. Total laid off by year (most recent year first)
-- The row with a NULL date appears as its own group at the end.

SELECT
	YEAR(`date`),
    SUM(total_laid_off) AS total_laid_off
FROM layoffs_cleaned
GROUP BY YEAR(`date`)
ORDER BY 1 DESC;

-- 2d. Total laid off by company funding stage

SELECT
	stage,
    SUM(total_laid_off) AS total_laid_off
FROM layoffs_cleaned
GROUP BY stage
ORDER BY 2 DESC;


/* ------------------------------------------------------------------------------
   Section 3. Layoff severity by company
   ------------------------------------------------------------------------------ */

-- Average percentage of the workforce laid off per company.
-- Complements the headcount view: a small company can lose 100% of its staff
-- while a large one loses only a small share. This is a simple average across
-- events, not weighted by company size.

SELECT
	company,
    AVG(percentage_laid_off) AS avg_percentage_laid_off
FROM layoffs_cleaned
GROUP BY company
ORDER BY 2 DESC;


/* ------------------------------------------------------------------------------
   Section 4. Progression over time
   ------------------------------------------------------------------------------ */

-- 4a. Total laid off per month
-- SUBSTRING(`date`, 1, 7) extracts 'YYYY-MM'. The WHERE clause drops the row
-- with no date.

SELECT SUBSTRING(`date`, 1, 7) AS MONTH, SUM(total_laid_off) AS total_laid_off
FROM layoffs_cleaned
WHERE SUBSTRING(`date`, 1, 7) IS NOT NULL
GROUP BY `MONTH`
ORDER BY 1;

-- 4b. Rolling (cumulative) total by month.
-- The CTE computes the monthly totals first. SUM() OVER (ORDER BY month) then
-- adds each month to the sum of all earlier months.

WITH Rolling_Total AS
(
	SELECT
		SUBSTRING(`date`, 1, 7) AS MONTH,
        SUM(total_laid_off) AS total_off
	FROM layoffs_cleaned
	WHERE SUBSTRING(`date`, 1, 7) IS NOT NULL
	GROUP BY `MONTH`
	ORDER BY 1
)
SELECT
	`MONTH`,
    total_off,
    SUM(total_off) OVER(ORDER BY `MONTH`) AS rolling_total
FROM Rolling_Total;


/* ------------------------------------------------------------------------------
   Section 5. Company rankings
   ------------------------------------------------------------------------------ */

-- 5a. Total laid off per company (baseline for the per-year breakdown below)

SELECT
	company,
    SUM(total_laid_off) AS total_laid_off
FROM layoffs_cleaned
GROUP BY company
ORDER BY 2 DESC;

-- 5b. Total laid off per company per year, largest first

SELECT
	company,
    YEAR(`date`),
    SUM(total_laid_off) AS total_laid_off
FROM layoffs_cleaned
GROUP BY company, YEAR(`date`)
ORDER BY 3 DESC;


-- 5c. Rank companies within each year.
-- DENSE_RANK() restarts at 1 for every year (PARTITION BY years) and does not
-- skip numbers after ties. Companies with no date are excluded.

WITH Company_Year(company, years, total_laid_off) AS
(
	SELECT
		company,
		YEAR(`date`),
		SUM(total_laid_off)
	FROM layoffs_cleaned
	GROUP BY company, YEAR(`date`)
)
SELECT
	*,
    DENSE_RANK() OVER(PARTITION BY years ORDER BY total_laid_off DESC) AS Ranking
FROM Company_Year
WHERE years IS NOT NULL
ORDER BY Ranking;

-- 5d. Top 5 companies per year.
-- A window function cannot be filtered in the same query level, so the ranking
-- is computed in a second CTE and filtered in the outer query.
-- Because DENSE_RANK() gives tied companies the same rank, a year can return
-- more than 5 rows when companies tie at rank 5.

WITH Company_Year(company, years, total_laid_off) AS
(
	SELECT
		company,
		YEAR(`date`),
		SUM(total_laid_off)
	FROM layoffs_cleaned
	GROUP BY company, YEAR(`date`)
), Company_Year_Rank AS
(
	SELECT
		*,
		DENSE_RANK() OVER(PARTITION BY years ORDER BY total_laid_off DESC) AS Ranking
	FROM Company_Year
	WHERE years IS NOT NULL
)
SELECT *
FROM Company_Year_Rank
WHERE Ranking <= 5;
