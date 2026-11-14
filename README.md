# Data-warehouse-project-using-duckdb-and-ducklocal-
complete dataware house project using duckdb and ducklocal building medillian architucture from source files from csv to complete clean files ready for data analysis

# 🧹 SQL Data Cleaning & Data Modeling Project

A beginner-friendly SQL project that takes **messy raw data** from two source systems (CRM and ERP), **cleans it**, and turns it into a **star schema** that is ready for reporting and analysis.

Built with **DuckDB** and plain **SQL**.

---

## 📌 Table of Contents

- [What This Project Does](#-what-this-project-does)
- [Project Structure](#-project-structure)
- [How the Data Flows](#-how-the-data-flows)
- [Part 1: Data Cleaning](#-part-1-data-cleaning)
- [Part 2: Data Modeling](#-part-2-data-modeling)
- [How to Run](#-how-to-run)
- [SQL Skills Used](#-sql-skills-used)
- [Acknowledgments](#-acknowledgments)
- [Contact Me](#-contact-me)

---

## 🎯 What This Project Does

Raw data is rarely perfect. It has duplicates, empty values, extra spaces, wrong dates and codes nobody can read. This project solves those problems step by step:

1. **Check** the data quality with simple queries.
2. **Clean** the data with SQL.
3. **Combine** the clean tables into a simple model that is easy to analyze.

---

## 📁 Project Structure

```
my-project/
├── datasets/                     # Raw source files (CRM and ERP)
├── scripts/
│   ├── data_cleaning_script.sql  # Part 1: quality checks + cleaning queries
│   └── data_model_script.sql     # Part 2: dimensions and fact table
├── .gitignore                    # Ignores the local *.duckdb file
└── README.md
```

---

## 🔄 How the Data Flows

```
 RAW DATA                   CLEAN DATA                    FINAL MODEL
┌──────────────┐         ┌─────────────────┐         ┌────────────────┐
│ cust_info    │         │ clean_cust_info │         │ dim_customer   │
│ CUST_AZ12    │  clean  │ clean_CUST_AZ12 │  join   │                │
│ LOC_A101     │ ──────► │ clean_LOC_A101  │ ──────► │ dim_product    │
│ prd_info     │         │ clean_prd_info  │         │                │
│ PX_CAT_G1V2  │         │ clean_PX_CAT... │         │ fact_sales     │
│ sales_details│         │ clean_sales_... │         │                │
└──────────────┘         └─────────────────┘         └────────────────┘
```

---

## 🧼 Part 1: Data Cleaning

**File:** [`scripts/data_cleaning_script.sql`](scripts/data_cleaning_script.sql)

Every table follows the same pattern: run a **check query** (it should return no rows), then apply the **fix**.

| Table | Problem Found | How It Is Fixed |
|-------|---------------|-----------------|
| `cust_info` | Duplicate or `NULL` customer ids | `ROW_NUMBER()` keeps only the latest record per customer |
| `cust_info` | Extra spaces in names | `TRIM()` |
| `cust_info` | Codes like `M`, `F`, `S` | `CASE WHEN` turns them into `Male`, `Female`, `Single`, `Married` |
| `prd_info` | `NULL` product costs | `COALESCE(prd_cost, 0)` |
| `prd_info` | End date earlier than start date | `LEAD()` builds the end date from the next start date |
| `prd_info` | Product codes like `M`, `R`, `T` | `CASE WHEN` turns them into `Mountain`, `Road`, `Touring` |
| `sales_details` | Dates stored as numbers (`20240115`) | `STRPTIME()` converts them to real dates |
| `sales_details` | Wrong sales, price or quantity values | Recalculated: `sales = quantity × price` |
| `CUST_AZ12` | Customer ids with an unwanted `NAS` prefix | `SUBSTRING()` removes the prefix |

### 💡 Quick Rule

> A good check query returns **no results**. If it returns rows, there is a data problem to fix.

---

## ⭐ Part 2: Data Modeling

**File:** [`scripts/data_model_script.sql`](scripts/data_model_script.sql)

The clean tables are combined into a **star schema**: one fact table in the middle, connected to two dimension tables.

```
   dim_customer ◄──────  fact_sales  ──────► dim_product
```

### 👤 `dim_customer`

Combines **3 tables** (customer info, birth date, country) into one.

- Adds a **surrogate key** (`customer_key`) with `ROW_NUMBER()`.
- **Gender rule:** the CRM value is used first. The ERP value is used only when the CRM value is `n/a`.

### 📦 `dim_product`

Combines product info with category info.

- Adds a **surrogate key** (`product_key`).
- Keeps **current products only** (`prd_end_dt IS NULL`), which removes history.

### 🛒 `fact_sales`

The sales transactions, linked to both dimensions through their surrogate keys (`product_key`, `customer_key`).

### ✅ Checks Included

- No duplicate customer or product ids after the joins.
- Every sale matches a product and a customer.

---

## ▶️ How to Run

**1. Install DuckDB** from [duckdb.org](https://duckdb.org/docs/installation/).

**2. Clone this repository**

```bash
git clone https://github.com/YOUR_USERNAME/YOUR_REPO.git
cd YOUR_REPO
```

**3. Load your raw data and run the scripts in order**

```bash
duckdb my_database.duckdb < scripts/data_cleaning_script.sql
duckdb my_database.duckdb < scripts/data_model_script.sql
```

> 📝 **Note:** The `.duckdb` database file is not stored in this repo. You rebuild it by running the `.sql` scripts.

---

## 🛠️ SQL Skills Used

- `GROUP BY` and `HAVING` to find duplicates
- Window functions: `ROW_NUMBER()`, `LEAD()`
- `CASE WHEN` for data standardization
- `TRIM()`, `SUBSTRING()`, `REPLACE()` for text cleaning
- `COALESCE()` and `NULLIF()` for handling `NULL`
- Date conversion with `STRPTIME()`
- `LEFT JOIN` across multiple tables
- Subqueries and views
- Surrogate keys and star schema design

---

## 🙏 Acknowledgments

This project was made possible with the help of:

- **[Baraa Salkini](https://www.youtube.com/@DataWithBaraa)**: I learned the project approach and SQL concepts from his tutorials.
- **[Claude](https://claude.ai)** (Anthropic): helped me refine, organize and document my SQL scripts.
- **[JetSquirrel](https://github.com/JetSquirrel)**: developer of [DuckLocal](https://github.com/JetSquirrel/DuckLocal), a local-first workspace for querying and exploring data with DuckDB, which helped me work with my data. See his [contributions](https://github.com/JetSquirrel/DuckLocal/commits?author=JetSquirrel).

Thank you all! 💙

---

## 📬 Contact Me

Questions, feedback or ideas? Reach out to me directly:

<p align="center">
  <a href="https://x.com/Paul_Atreides52">
    <img src="https://img.shields.io/badge/X-Follow%20Me-000000?style=for-the-badge&logo=x&logoColor=white" alt="X (Twitter)" />
  </a>
  <a href="https://www.facebook.com/mhmd.kamal.164329">
    <img src="https://img.shields.io/badge/Facebook-Message%20Me-1877F2?style=for-the-badge&logo=facebook&logoColor=white" alt="Facebook" />
  </a>
  <a href="https://www.linkedin.com/in/mohammed-kamal-909649178/">
    <img src="https://img.shields.io/badge/LinkedIn-Connect%20With%20Me-0A66C2?style=for-the-badge&logo=linkedin&logoColor=white" alt="LinkedIn" />
  </a>
</p>

---

<p align="center">⭐ If you found this project helpful, please give it a star! ⭐</p>
