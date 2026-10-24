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
   6. Severity by industry and funding stage
   7. Estimated company size and layoff percentage by size
   8. Change over time: year-over-year, month-over-month, per-month average
   9. Funding and company closure rate
   10. Concentration: share of layoffs from the top 10 companies
   11. Top 3 industries per year

   Reading the results
   -------------------
   - total_laid_off is NULL in 378 of the 1,995 rows, so every SUM() below only
     counts events with a known headcount. Totals are a lower bound.
   - percentage_laid_off is a fraction (1 = 100% of the workforce).
   - Sorting by column position (ORDER BY 2) sorts by the second selected column.
   - NULL totals sort last when ordering from high to low.
   - 2023 covers only January to early March, so compare years by monthly
     average (Section 8c), not by yearly total.

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


/* ------------------------------------------------------------------------------
   Section 6. Layoff severity by industry and funding stage
   ------------------------------------------------------------------------------ */
   
-- 6a. Headcount and severity side by side, by industry.
-- total_laid_off shows the scale, avg_percentage_laid_off shows how deep the cuts
-- went, and COUNT(*) is the number of layoff events behind each average.
-- HAVING drops groups with fewer than 10 events, because an average of two or
-- three events is not reliable.

SELECT
	industry,
    COUNT(*) AS events,
    SUM(total_laid_off) AS total_laid_off,
    ROUND(AVG(percentage_laid_off), 2) AS avg_percentage_laid_off
FROM layoffs_cleaned
GROUP BY industry
HAVING COUNT(*) >= 10
ORDER BY 4 DESC;

-- 6b. Same view by funding stage (only the grouping column changes)

SELECT
	stage,
    COUNT(*) AS events,
    SUM(total_laid_off) AS total_laid_off,
    ROUND(AVG(percentage_laid_off), 2) AS avg_percentage_laid_off
FROM layoffs_cleaned
GROUP BY stage
HAVING COUNT(*) >= 10
ORDER BY 4 DESC;


/* ------------------------------------------------------------------------------
   Section 7. Estimated company size
   Idea: if a company laid off 500 people and that was 5% of its workforce, it had
   about 500 / 0.05 = 10,000 employees. The dataset has no company size column,
   so this estimate lets us compare large and small companies fairly.
   ------------------------------------------------------------------------------ */
 
-- 7a. Estimated company size before each layoff (ten largest).
-- Both figures must be known. NULLIF turns a percentage of 0 into NULL, so the
-- division returns NULL instead of failing. The source percentages are rounded,
-- so treat the result as an approximation.

SELECT
	company,
    `date`,
    total_laid_off,
    percentage_laid_off,
    ROUND(total_laid_off / NULLIF(percentage_laid_off, 0)) AS estimated_company_size
FROM layoffs_cleaned
WHERE total_laid_off IS NOT NULL
AND percentage_laid_off IS NOT NULL
ORDER BY estimated_company_size DESC
LIMIT 10;

-- 7b. Do bigger companies cut a smaller share of their workforce?
-- The first CTE estimates the size, the second CTE labels each event with a size
-- bucket using CASE, and the final query averages the percentage per bucket.
-- The numbers in the bucket names make ORDER BY sort the buckets in size order.
-- Each bucket includes its lower limit: a size of exactly 1,000 falls in Large.

WITH Company_Size AS
(
	SELECT
		company,
        percentage_laid_off,
        total_laid_off / NULLIF(percentage_laid_off, 0) AS estimated_size
	FROM layoffs_cleaned
    WHERE total_laid_off IS NOT NULL
    AND percentage_laid_off IS NOT NULL
), Size_Bucket AS 
(
	SELECT
		percentage_laid_off,
        CASE
			WHEN estimated_size < 100 THEN '1. Small (under 100)'
            WHEN estimated_size < 1000 THEN '2. Medium (100 to 999)'
            WHEN estimated_size < 10000 THEN '3. Large (1000 to 9999)'
            ELSE '4. Very Large (10000 or more)'
		END AS size_bucket
	FROM Company_Size
    WHERE estimated_size IS NOT NULL
)
SELECT
	size_bucket,
    COUNT(*) AS events,
    ROUND(AVG(percentage_laid_off), 2) AS avg_percentage_laid_off
FROM Size_Bucket
GROUP BY size_bucket
ORDER BY size_bucket;


/* ------------------------------------------------------------------------------
   Section 8. Change over time
   ------------------------------------------------------------------------------ */

-- 8a. Year-over-year change in total layoffs.
-- LAG(total_laid_off) looks one row back in year order, so each year can be
-- compared with the year before it. The first year has no previous row, so LAG
-- returns NULL there. The second CTE stores the LAG result once, so it is not
-- repeated in every calculation.
-- Note: 2023 only covers January to early March, so its change is not a
-- full-year comparison (see 8c).

WITH Yearly_Total AS
(
	SELECT
		YEAR(`date`) AS years,
        SUM(total_laid_off) AS total_laid_off
    FROM layoffs_cleaned
    WHERE `date` IS NOT NULL
    GROUP BY YEAR(`date`)
), Yearly_Previous AS
(
	SELECT
		years,
        total_laid_off,
        LAG(total_laid_off) OVER(ORDER BY years) AS previous_year_total
	FROM Yearly_Total
)
SELECT
	years,
    total_laid_off,
    previous_year_total,
    total_laid_off - previous_year_total AS change_in_total,
    ROUND(100 * (total_laid_off - previous_year_total) / NULLIF(previous_year_total, 0), 1) AS change_pct
FROM Yearly_Previous;

-- 8b. Month-over-month change in total layoffs.
-- Same pattern as 8a, with months instead of years.
-- If a calendar month has no layoffs at all, it has no row, and LAG compares
-- with the closest earlier month that does.

WITH Monthly_Total AS
(
	SELECT
		SUBSTRING(`date`, 1, 7) AS MONTH,
        SUM(total_laid_off) AS total_laid_off
    FROM layoffs_cleaned
    WHERE `date` IS NOT NULL
    GROUP BY `MONTH`
), Monthly_Previous AS
(
	SELECT
		`MONTH`,
        total_laid_off,
        LAG(total_laid_off) OVER(ORDER BY `MONTH`) AS previous_month_total
    FROM Monthly_Total
)
SELECT
	`MONTH`,
    total_laid_off,
    previous_month_total,
    ROUND(100 * (total_laid_off - previous_month_total) / NULLIF(previous_month_total, 0), 1) AS change_pct
FROM Monthly_Previous;

-- 8c. Average layoffs per month in each year.
-- A fair comparison when a year is incomplete: divide each year's total by the
-- number of months that actually have data.

SELECT
	YEAR(`date`) AS years,
    COUNT(DISTINCT SUBSTRING(`date`, 1, 7)) AS months_with_data,
    SUM(total_laid_off) AS total_laid_off,
    ROUND(SUM(total_laid_off) / COUNT(DISTINCT SUBSTRING(`date`, 1, 7))) AS avg_per_month
FROM layoffs_cleaned
WHERE `date` IS NOT NULL
GROUP BY YEAR(`date`)
ORDER BY 1;


/* ------------------------------------------------------------------------------
   Section 9. Funding and company closure
   Question: do companies that raised more money close less often?
   Here "closure" means a layoff of 100% of the workforce (percentage_laid_off = 1).
   ------------------------------------------------------------------------------ */

-- 9a. Closure rate by funding stage.
-- The CASE inside SUM() counts the events where the whole workforce was laid off.
-- COUNT(percentage_laid_off) counts only events with a known percentage, so the
-- rate is not pulled down by rows where the percentage is missing.
-- HAVING drops stages with fewer than 10 such events.

SELECT
	stage,
    COUNT(percentage_laid_off) AS events_with_percentage,
    SUM(CASE WHEN percentage_laid_off = 1 THEN 1 ELSE 0 END) AS fully_laid_off,
    ROUND(100 * SUM(CASE WHEN percentage_laid_off = 1 THEN 1 ELSE 0 END) / COUNT(percentage_laid_off), 1) AS closure_rate_pct
FROM layoffs_cleaned
GROUP BY stage
HAVING COUNT(percentage_laid_off) >= 10
ORDER BY 4 DESC;

-- 9b. Closure rate by amount of funding raised.
-- The CTE puts each event into a funding band with CASE, so the band logic is
-- written once and the final query can simply GROUP BY it. Events with unknown
-- funding get their own band instead of being dropped.

WITH Funding_Band AS
(
	SELECT
		percentage_laid_off,
        CASE
			WHEN funds_raised_millions IS NULL THEN '5. Unknown'
            WHEN funds_raised_millions < 10 THEN '1. Under 10M'
            WHEN funds_raised_millions < 100 THEN '2. 10M to 99M'
            WHEN funds_raised_millions < 1000 THEN '3. 100M to 999M'
            ELSE '4. 1B or more'
		END AS funding_band
	FROM layoffs_cleaned
    WHERE percentage_laid_off IS NOT NULL
)
SELECT
	funding_band,
    COUNT(*) AS events,
    SUM(CASE WHEN percentage_laid_off = 1 THEN 1 ELSE 0 END) AS fully_laid_off,
    ROUND(100 * SUM(CASE WHEN percentage_laid_off = 1 THEN 1 ELSE 0 END) / COUNT(*), 1) AS closure_rate_pct
FROM Funding_Band
GROUP BY funding_band
ORDER BY funding_band;


/* ------------------------------------------------------------------------------
   Section 10. How concentrated were the layoffs?
   Question: what share of all layoffs came from the ten biggest companies?
   ------------------------------------------------------------------------------ */

-- 10a. Top 10 companies with their share of all layoffs.
-- The first CTE totals each company (rows with an unknown headcount are left out).
-- The second CTE ranks the companies and, in the same step, adds the grand total
-- to every row with SUM() OVER (): an empty OVER() means "all rows".
-- The outer WHERE keeps only the top 10 AFTER the grand total was calculated, so
-- every share is a share of ALL companies. Filtering earlier would shrink the total.
-- company is the tie-breaker in ROW_NUMBER so the order is the same on every run.

WITH Company_Total AS
(
	SELECT
		company,
        SUM(total_laid_off) AS total_laid_off
    FROM layoffs_cleaned
    WHERE total_laid_off IS NOT NULL
    GROUP BY company
), Company_Ranked AS
(
	SELECT
		company,
        total_laid_off,
        ROW_NUMBER() OVER(ORDER BY total_laid_off DESC, company) AS company_rank,
        SUM(total_laid_off) OVER() AS grand_total
	FROM Company_Total
)
SELECT
	company_rank,
    company,
    total_laid_off,
    ROUND(100 * total_laid_off / grand_total, 1) AS share_pct,
    ROUND(100 * SUM(total_laid_off) OVER(ORDER BY company_rank) / grand_total, 1) AS cumulative_share_pct
FROM Company_Ranked
WHERE company_rank <= 10;


/* ------------------------------------------------------------------------------
   Section 11. Which industries led each year?
   ------------------------------------------------------------------------------ */

-- 11a. Top 3 industries per year.
-- Steps:
--   1. First CTE: total laid off per industry per year.
--   2. Second CTE: rank the industries within each year with DENSE_RANK().
--   3. Final query: keep rank 3 or better, sorted by year and then by rank.

-- Note: the first CTE keeps only rows with a known headcount, and the second
-- CTE drops the row with no date. Rank 3 had no ties in any year, so each year
-- returns exactly 3 rows.

WITH Industry_Total AS
(
	SELECT
		industry,
        YEAR(`date`) AS years,
        SUM(total_laid_off) AS total_laid_off
    FROM layoffs_cleaned
    WHERE total_laid_off IS NOT NULL
    GROUP BY industry, YEAR(`date`)
), Industry_Ranked AS
(
	SELECT
		industry,
        years,
        total_laid_off,
        DENSE_RANK() OVER(PARTITION BY years ORDER BY total_laid_off DESC) AS industry_rank
    FROM Industry_Total
    WHERE years IS NOT NULL
)
SELECT
	industry_rank,
    industry,
    years,
    total_laid_off
FROM Industry_Ranked
WHERE industry_rank <= 3
ORDER BY years, industry_rank;