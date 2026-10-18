<h1 align="center">📉 Layoffs Data Cleaning and EDA using SQL</h1>

<p align="center">
An end-to-end MySQL project that cleans a raw global tech layoffs dataset and then explores it to find which companies, industries, countries, and years were hit hardest, using staging tables, window functions, CTEs, and self joins.
</p>

<hr>

<h2>📌 Project Overview</h2>

<p>
Raw data is rarely ready for analysis. This project takes a messy <b>layoffs dataset (March 2020 to March 2023)</b> and works through it in two phases: <b>data cleaning</b> to make the data reliable, and <b>exploratory data analysis (EDA)</b> to answer questions about it.
</p>

<p>
The cleaning phase never touches the raw table. All changes happen on a <b>staging copy</b>, so the original data stays intact and every step can be repeated or checked.
</p>

<ul>
<li>Removing duplicate records using <code>ROW_NUMBER()</code> and a CTE</li>
<li>Standardizing text, country names, and date formats</li>
<li>Handling NULL and blank values, including filling gaps with a self join</li>
<li>Dropping rows and columns that carry no usable information</li>
<li>Analyzing layoffs by company, industry, country, stage, and time period</li>
<li>Building rolling monthly totals and yearly company rankings</li>
</ul>

<hr>

<h2>❓ Questions This Project Answers</h2>

<ul>
<li>Which companies laid off the most employees in total?</li>
<li>Which companies shut down completely (100% laid off), and how much funding had they raised?</li>
<li>Which industries and countries were affected the most?</li>
<li>How did layoffs change year by year and month by month?</li>
<li>Who were the top 5 companies by layoffs in each year?</li>
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
<li>CTEs and window functions (<code>ROW_NUMBER</code>, <code>DENSE_RANK</code>, rolling <code>SUM() OVER</code>)</li>
<li>String functions (<code>TRIM</code>, <code>SUBSTRING</code>) and <code>STR_TO_DATE</code></li>
<li>Self joins, <code>UPDATE</code>, <code>ALTER TABLE</code>, <code>DELETE</code></li>
<li><code>GROUP BY</code>, aggregate functions, and <code>ORDER BY</code></li>
</ul>

<hr>

<h2>📂 Project Structure</h2>

<pre>
layoffs-data-cleaning-eda-sql/
│
├── README.md
├── .gitignore
├── LICENSE
│
├── data/
│   ├── raw/
│   │   └── layoffs.csv                    # Original dataset (never edited)
│   └── cleaned/
│       └── layoffs_cleaned.csv            # Final table exported after cleaning
│
├── sql/
│   ├── 01_data_cleaning.sql               # Phase 1: cleaning pipeline
│   └── 02_exploratory_data_analysis.sql   # Phase 2: EDA queries
│
└── images/                                # Screenshots of key results (optional)
</pre>

<hr>

<h2>🧹 Phase 1: Data Cleaning</h2>

<p>File: <code>sql/01_data_cleaning.sql</code></p>

<ol>
<li><b>Create a staging table</b> as a copy of the raw table, so the raw data is preserved</li>
<li><b>Remove duplicates</b> by numbering rows with <code>ROW_NUMBER() OVER (PARTITION BY ...)</code> inside a CTE and deleting the repeats</li>
<li><b>Standardize the data</b>
  <ul>
  <li>Trim extra spaces in company names</li>
  <li>Merge variations of the same value in <code>industry</code> (for example, different spellings of "Crypto")</li>
  <li>Fix inconsistent <code>country</code> values, such as a trailing period</li>
  <li>Convert <code>date</code> from text with <code>STR_TO_DATE</code> and change the column type to <code>DATE</code></li>
  </ul>
</li>
<li><b>Handle NULL and blank values</b>
  <ul>
  <li>Turn blank strings into NULL</li>
  <li>Fill missing <code>industry</code> values from other rows of the same company using a self join</li>
  </ul>
</li>
<li><b>Remove unusable rows and columns</b>
  <ul>
  <li>Delete rows where both <code>total_laid_off</code> and <code>percentage_laid_off</code> are NULL</li>
  <li>Drop the helper <code>row_num</code> column</li>
  </ul>
</li>
</ol>

<h3>Data Quality Summary</h3>

<table>
<tr><th>Metric</th><th>Value</th></tr>
<tr><td>Rows in raw table</td><td>XXXX</td></tr>
<tr><td>Duplicate rows removed</td><td>XX</td></tr>
<tr><td>Rows removed with no layoff data</td><td>XXX</td></tr>
<tr><td>Rows in final cleaned table</td><td>XXXX</td></tr>
</table>

<hr>

<h2>🔍 Phase 2: Exploratory Data Analysis</h2>

<p>File: <code>sql/02_exploratory_data_analysis.sql</code></p>

<ul>
<li>Maximum layoffs in a single event and highest layoff percentage</li>
<li>Companies that laid off 100% of staff, ordered by funds raised</li>
<li>Total layoffs by company, industry, country, funding stage, and year</li>
<li>Date range covered by the data</li>
<li>Monthly layoffs with a <b>rolling total</b> built with a CTE and <code>SUM() OVER</code></li>
<li>Top 5 companies per year using <code>DENSE_RANK() OVER (PARTITION BY year ORDER BY total)</code></li>
</ul>

<hr>

<h2>📊 Key Findings</h2>

<p><i>Replace the values below with the results from your own run.</i></p>

<ul>
<li><b>Company with the most layoffs overall:</b> XXXX (XX,XXX employees)</li>
<li><b>Most affected industry:</b> XXXX</li>
<li><b>Most affected country:</b> XXXX</li>
<li><b>Year with the most layoffs:</b> XXXX</li>
<li><b>Companies that shut down completely:</b> XXX, with XXXX the best funded</li>
<li><b>Trend:</b> one or two sentences on how monthly layoffs moved over time</li>
</ul>

<hr>

<h2>🚀 How to Run</h2>

<h3>1️⃣ Clone the Repository</h3>
<pre>
git clone https://github.com/UmeshBhabad/layoffs-data-cleaning-eda-sql.git
cd layoffs-data-cleaning-eda-sql
</pre>

<h3>2️⃣ Create the Database and Import the Raw Data</h3>
<pre>
CREATE DATABASE world_layoffs;
USE world_layoffs;
</pre>
<p>In MySQL Workbench, right-click <b>Tables → Table Data Import Wizard</b>, choose <code>data/raw/layoffs.csv</code>, and import it as a table named <code>layoffs</code>.</p>

<h3>3️⃣ Run the Cleaning Script</h3>
<p>Open <code>sql/01_data_cleaning.sql</code> and run it <b>one statement at a time</b> so you can check the result of each step.</p>

<h3>4️⃣ Run the EDA Script</h3>
<p>Open <code>sql/02_exploratory_data_analysis.sql</code>. It reads from the cleaned staging table created in step 3.</p>

<hr>

<h2>🧠 Design Highlights</h2>

<ul>
<li><b>Raw Data Preserved</b> — all cleaning happens on a staging copy, so mistakes are never permanent</li>
<li><b>Repeatable Pipeline</b> — scripts run top to bottom on a fresh import and produce the same result</li>
<li><b>Verified Cleaning</b> — each step is followed by a check query that proves the fix worked</li>
<li><b>Question-Driven EDA</b> — every query answers a specific business question instead of just exploring</li>
</ul>

<hr>

<h2>🔮 Future Enhancements</h2>

<ul>
<li>Visualize the EDA results in Tableau, Power BI, or Excel and add the dashboard screenshots to <code>images/</code></li>
<li>Re-implement the cleaning pipeline in Python (pandas) to compare both approaches</li>
<li>Wrap the cleaning steps in a stored procedure for one-click reruns</li>
<li>Add indexes on frequently grouped columns and compare query plans with <code>EXPLAIN</code></li>
</ul>

<hr>

<h2>📖 Source</h2>

<p>
Project steps follow the data cleaning and exploratory data analysis mini projects in <i>Learn SQL Beginner to Advanced in Under 4 Hours</i> by <b>Alex The Analyst</b> (<a href="https://youtu.be/OT1RErkfLNQ">YouTube</a>). The dataset comes from that course. Queries, notes, and findings are my own work.
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