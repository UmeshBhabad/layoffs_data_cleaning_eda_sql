<h1 align="center">📉 Layoffs Data Cleaning and EDA using SQL</h1>

<p align="center">
An end-to-end MySQL project that cleans a raw global tech layoffs dataset and then explores it to find which companies, industries, countries, and years were hit hardest, using staging tables, window functions, CTEs, and self joins.
</p>

<hr>

<h2>🚦 Project Status</h2>

<ul>
<li>✅ <b>Phase 1: Data Cleaning</b> — complete (<a href="sql/01_data_cleaning.sql">sql/01_data_cleaning.sql</a>)</li>
<li>✅ <b>Phase 2: Exploratory Data Analysis</b> — complete (<a href="sql/02_exploratory_data_analysis.sql">sql/02_exploratory_data_analysis.sql</a>)</li>
<li>🔜 <b>Next:</b> dashboard in Power BI</li>
</ul>

<hr>

<h2>📌 Project Overview</h2>

<p>
Raw data is rarely ready for analysis. This project takes a messy <b>layoffs dataset (March 2020 to March 2023)</b> and works through it in two phases: <b>data cleaning</b> to make the data reliable, and <b>exploratory data analysis (EDA)</b> to answer questions about it.
</p>

<p>
The cleaning phase never touches the raw table. All changes happen on <b>staging copies</b>, so the original data stays intact and every step can be repeated or checked.
</p>

<ul>
<li>Removing duplicate records using <code>ROW_NUMBER()</code> and a CTE</li>
<li>Standardizing text, country names, and date formats</li>
<li>Handling NULL and blank values, including filling gaps with a self join</li>
<li>Dropping rows and columns that carry no usable information</li>
<li>Converting the percentage column from text to <code>DECIMAL(5,4)</code> for numeric analysis</li>
<li>Analyzing layoffs by company, industry, country, stage, and time period <i>(Phase 2)</i></li>
<li>Building rolling monthly totals, yearly rankings, and year-over-year change <i>(Phase 2)</i></li>
<li>Testing questions the course did not cover: company size, funding versus closure, and concentration <i>(Phase 2)</i></li>
</ul>

<hr>

<h2>❓ Questions This Project Answers</h2>

<ul>
<li>Which companies laid off the most employees in total?</li>
<li>Which companies shut down completely (100% laid off), and how much funding had they raised?</li>
<li>Which industries and countries were affected the most?</li>
<li>How did layoffs change year by year and month by month?</li>
<li>Who were the top 5 companies by layoffs in each year?</li>
<li>Did larger companies cut a smaller share of their workforce?</li>
<li>Did companies that raised more money shut down less often?</li>
<li>How concentrated were the layoffs among a few companies?</li>
</ul>

<hr>

<h2>🗃️ Dataset</h2>

<p>
The dataset contains one row per layoff event. The raw file is stored in <code>data/raw/layoffs.csv</code> and is never edited.
</p>

<table>
<tr><th>Column</th><th>Description</th></tr>
<tr><td><code>company</code></td><td>Company that announced the layoff</td></tr>
<tr><td><code>location</code></td><td>City or region of the company</td></tr>
<tr><td><code>industry</code></td><td>Industry the company belongs to</td></tr>
<tr><td><code>total_laid_off</code></td><td>Number of employees laid off</td></tr>
<tr><td><code>percentage_laid_off</code></td><td>Share of the workforce laid off (1 = 100%)</td></tr>
<tr><td><code>date</code></td><td>Date of the layoff announcement</td></tr>
<tr><td><code>stage</code></td><td>Funding stage of the company (Seed, Series A, Post-IPO, and so on)</td></tr>
<tr><td><code>country</code></td><td>Country of the company</td></tr>
<tr><td><code>funds_raised_millions</code></td><td>Total funding raised, in millions of USD</td></tr>
</table>

<hr>

<h2>🛠️ Tech Stack</h2>

<ul>
<li><b>Database:</b> MySQL 8.x</li>
<li><b>Client:</b> MySQL Workbench</li>
<li><b>Version Control:</b> Git and GitHub</li>
</ul>

<h3>SQL Concepts Used</h3>

<ul>
<li>Staging tables (<code>CREATE TABLE ... LIKE</code>, <code>INSERT INTO ... SELECT</code>)</li>
<li>CTEs and window functions (<code>ROW_NUMBER</code>, <code>DENSE_RANK</code>, <code>LAG</code>, rolling and grand-total <code>SUM() OVER</code>)</li>
<li>String functions (<code>TRIM</code>) and <code>STR_TO_DATE</code></li>
<li>Self joins, <code>UPDATE</code>, <code>ALTER TABLE</code>, <code>DELETE</code></li>
<li><code>GROUP BY</code>, <code>HAVING</code>, aggregate functions, and <code>ORDER BY</code></li>
<li><code>CASE</code> for banding and rate calculations, <code>NULLIF</code> to avoid divide-by-zero</li>
</ul>

<hr>

<h2>📂 Project Structure</h2>

<pre>
layoffs_data_cleaning_eda_sql/
│
├── README.md
├── .gitignore
├── LICENSE
│
├── data/
│   └── raw/
│       └── layoffs.csv                    # Original dataset (never edited)
│
└── sql/
    ├── 01_data_cleaning.sql               # Phase 1: cleaning pipeline
    └── 02_exploratory_data_analysis.sql   # Phase 2: EDA queries (11 sections)
</pre>

<p>
The cleaned table is created by running <code>01_data_cleaning.sql</code>. It is stored in the database as <code>layoffs_cleaned</code>.
</p>

<hr>

<h2>🧹 Phase 1: Data Cleaning</h2>

<p>File: <code>sql/01_data_cleaning.sql</code></p>

<ol>
<li><b>Create a staging table</b> as a copy of the raw table, so the raw data is preserved</li>
<li><b>Remove duplicates</b> by numbering rows with <code>ROW_NUMBER() OVER (PARTITION BY ...)</code> inside a CTE, then deleting the repeats from a second staging table (MySQL cannot delete directly from a CTE)</li>
<li><b>Standardize the data</b>
  <ul>
  <li>Trim extra spaces in company names</li>
  <li>Merge three spellings of the same industry (<code>Crypto</code>, <code>Crypto Currency</code>, <code>CryptoCurrency</code>) into <code>Crypto</code></li>
  <li>Fix <code>United States.</code> (trailing period) so it matches <code>United States</code></li>
  <li>Convert <code>date</code> from text with <code>STR_TO_DATE</code> and change the column type to <code>DATE</code></li>
  <li>Convert <code>percentage_laid_off</code> from text to <code>DECIMAL(5,4)</code> so it can be averaged and compared</li>
  </ul>
</li>
<li><b>Handle NULL and blank values</b>
  <ul>
  <li>Turn blank strings into NULL</li>
  <li>Fill missing <code>industry</code> values from other rows of the same company and location using a self join</li>
  </ul>
</li>
<li><b>Remove unusable rows and columns</b>
  <ul>
  <li>Delete rows where both <code>total_laid_off</code> and <code>percentage_laid_off</code> are NULL</li>
  <li>Drop the helper <code>row_num</code> column</li>
  </ul>
</li>
<li><b>Rename the final table</b> from <code>layoffs_staging2</code> to <code>layoffs_cleaned</code></li>
</ol>

<h3>Data Quality Summary</h3>

<table>
<tr><th>Metric</th><th>Value</th></tr>
<tr><td>Rows in raw table</td><td>2,361</td></tr>
<tr><td>Duplicate rows removed</td><td>5</td></tr>
<tr><td>Rows removed with no layoff data</td><td>361</td></tr>
<tr><td><b>Rows in final cleaned table</b></td><td><b>1,995</b></td></tr>
<tr><td>Missing industries filled from the same company</td><td>3</td></tr>
<tr><td>Date range</td><td>2020-03-11 to 2023-03-06</td></tr>
<tr><td>Distinct companies / countries / industries</td><td>1,633 / 51 / 31</td></tr>
</table>

<h3>Known Limitations</h3>

<p>
Cleaning does not invent values, so some NULLs remain in the final table. Keep these in mind when reading the analysis:
</p>

<table>
<tr><th>Column</th><th>Rows still NULL</th></tr>
<tr><td><code>total_laid_off</code></td><td>378</td></tr>
<tr><td><code>percentage_laid_off</code></td><td>423</td></tr>
<tr><td><code>funds_raised_millions</code></td><td>165</td></tr>
<tr><td><code>stage</code></td><td>5</td></tr>
<tr><td><code>industry</code></td><td>1 (Bally's Interactive, which has only one record)</td></tr>
<tr><td><code>date</code></td><td>1</td></tr>
</table>

<p>
Every remaining row has at least one of <code>total_laid_off</code> or <code>percentage_laid_off</code>. Because 378 headcounts are missing, every total in the analysis is a <b>lower bound</b>.
</p>

<hr>

<h2>🔍 Phase 2: Exploratory Data Analysis</h2>

<p>File: <a href="sql/02_exploratory_data_analysis.sql">sql/02_exploratory_data_analysis.sql</a></p>

<p>Sections 1 to 5 follow the course. Sections 6 to 11 are my own extensions.</p>

<table>
<tr><th>#</th><th>Section</th><th>Key technique</th></tr>
<tr><td>1</td><td>Extremes and period covered</td><td><code>MAX</code>, <code>MIN</code></td></tr>
<tr><td>2</td><td>Totals by industry, country, year, stage</td><td><code>GROUP BY</code></td></tr>
<tr><td>3</td><td>Severity by company</td><td><code>AVG</code></td></tr>
<tr><td>4</td><td>Monthly totals and rolling total</td><td>CTE, <code>SUM() OVER (ORDER BY)</code></td></tr>
<tr><td>5</td><td>Company rankings per year</td><td><code>DENSE_RANK() OVER (PARTITION BY)</code></td></tr>
<tr><td>6</td><td>Severity by industry and stage</td><td><code>HAVING</code> for minimum sample size</td></tr>
<tr><td>7</td><td>Estimated company size</td><td><code>NULLIF</code>, <code>CASE</code> buckets</td></tr>
<tr><td>8</td><td>Year-over-year and month-over-month change</td><td><code>LAG</code></td></tr>
<tr><td>9</td><td>Funding and closure rate</td><td><code>SUM(CASE ...)</code> rates</td></tr>
<tr><td>10</td><td>Concentration in the top 10 companies</td><td><code>SUM() OVER ()</code>, cumulative share</td></tr>
<tr><td>11</td><td>Top 3 industries per year</td><td>Two CTEs + <code>DENSE_RANK</code></td></tr>
</table>

<hr>

<h2>📊 Key Findings</h2>

<p>
Totals count only events with a known headcount (1,617 of 1,995 rows), so they are <b>lower bounds</b>. The dataset records about <b>383,659</b> layoffs between March 2020 and March 2023.
</p>

<ul>
<li><b>Layoffs peaked at the end of the data.</b> The largest single events were Google (12,000, Jan 2023), Meta (11,000, Nov 2022) and Amazon (10,000, Nov 2022). January 2023 alone had 84,714 recorded layoffs, the highest month in the dataset.</li>
<li><b>2023 is not a full year.</b> It covers only January to early March, so its yearly total understates it. Per month, 2023 averaged about 41,900 layoffs, against about 13,400 in 2022, 1,400 in 2021 and 8,100 in 2020 (section 8c).</li>
<li><b>Layoffs were concentrated.</b> The top 10 companies out of 1,328 account for about <b>25.7%</b> of all layoffs, with Amazon the largest at 4.7%.</li>
<li><b>Leading industries changed every year:</b> Transportation (2020), Consumer (2021), Retail (2022) and Other (2023). Consumer, Retail and Other lead the all-time totals, and Consumer appears in the top 3 for 2021, 2022 and 2023.</li>
<li><b>The United States dominates by headcount</b> (about 256,600), followed by India (about 36,000) and the Netherlands (about 17,200).</li>
<li><b>Larger companies cut a smaller share of staff.</b> Average percentage laid off falls from 0.46 for companies under 100 employees to 0.07 for those with 10,000 or more (company size is estimated from headcount and percentage).</li>
<li><b>Early-stage companies were far more likely to shut down.</b> Seed-stage events had a 48.9% closure rate (average 70% of staff cut), against 1.0% for Post-IPO companies.</li>
<li><b>More funding, fewer closures.</b> Closure rate falls from 38.2% for companies with under $10M raised, to 9.8% for $10M to $99M, to 1.7% for $100M to $999M. The $1B+ band shows 3.6%, but it has only 140 events, so treat it with caution.</li>
</ul>

<h3>Caveats</h3>

<ul>
<li><b>Missing data:</b> total_laid_off is NULL in 378 rows and percentage_laid_off in 423, so totals are lower bounds and rates use only rows with known values.</li>
<li><b>Estimated company size</b> is derived from rounded percentages, so it is approximate.</li>
<li><b>"Closure"</b> means 100% of staff laid off in an event, which may not mean the company ceased to exist.</li>
<li><b>Case variants</b> of company names (for example <code>SalesLoft</code> and <code>Salesloft</code>) are merged by MySQL's case-insensitive collation in <code>GROUP BY</code>, and were left as they are in the table.</li>
<li><b>May 2021</b> has no rows, so the month-over-month comparison for June 2021 is against April.</li>
</ul>

<hr>

<h2>🚀 How to Run</h2>

<h3>1️⃣ Clone the Repository</h3>
<pre>
git clone https://github.com/UmeshBhabad/layoffs_data_cleaning_eda_sql.git
cd layoffs_data_cleaning_eda_sql
</pre>

<h3>2️⃣ Create the Database and Import the Raw Data</h3>
<pre>
CREATE DATABASE world_layoffs;
USE world_layoffs;
</pre>
<p>In MySQL Workbench, right-click <b>Tables → Table Data Import Wizard</b>, choose <code>data/raw/layoffs.csv</code>, and import it as a table named <code>layoffs</code>. The table should have 2,361 rows, and missing values must be real NULLs: <code>SELECT COUNT(*) FROM layoffs WHERE total_laid_off IS NULL;</code> should return 740.</p>

<h3>3️⃣ Run the Cleaning Script</h3>
<p>Open <code>sql/01_data_cleaning.sql</code> and run it <b>one statement at a time</b> so you can check the result of each step. Expected row counts: 2,361 at the start, 2,356 after removing duplicates, and 1,995 at the end.</p>

<hr>

<h2>🧠 Design Highlights</h2>

<ul>
<li><b>Raw Data Preserved</b> — all cleaning happens on staging copies, so mistakes are never permanent</li>
<li><b>Repeatable Pipeline</b> — the script runs top to bottom on a fresh import and produces the same result</li>
<li><b>Verified Cleaning</b> — each step is followed by a check query that proves the fix worked</li>
<li><b>Honest Handling of Missing Data</b> — values are filled only when another row of the same company supports it, never guessed</li>
</ul>

<hr>

<h2>🔮 Future Enhancements</h2>

<ul>
<li>Build a Power BI dashboard from the key query results and add screenshots here</li>
<li>Re-implement the cleaning pipeline in Python (pandas) and compare the results</li>
<li>Wrap the cleaning steps in a stored procedure for one-click reruns</li>
</ul>

<hr>

<h2>📖 Source</h2>

<p>
Project steps follow the data cleaning and exploratory data analysis mini projects in <i>Learn SQL Beginner to Advanced in Under 4 Hours</i> by <b>Alex The Analyst</b> (<a href="https://youtu.be/OT1RErkfLNQ">YouTube</a>). The dataset comes from that course. Notes, checks, and the documented data quality results are my own work.
</p>

<hr>

<h2>👨‍💻 Author</h2>

<p>
<b>Umesh Shivaji Bhabad</b><br>
📫 umeshbhabad9@gmail.com
</p>

<hr>

<h2>⭐ Support</h2>

<p>If you find this project useful, consider giving it a ⭐ on GitHub!</p>