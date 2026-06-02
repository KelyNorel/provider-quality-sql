# Provider Quality Analysis — CMS Hospital Data

Analysis of U.S. hospital quality using public CMS (Centers for Medicare & Medicaid Services) data. 
Designed to mirror the type of provider evaluation work done at companies like Garner Health.

---

## Motivation

Healthcare quality varies dramatically across hospitals, states, and ownership types — 
but that variation is rarely visible to patients or employers. This project uses 
real CMS data to surface those differences using SQL-first analysis in DuckDB.

---

## Data Sources

Downloaded manually from the [CMS Provider Data Catalog](https://data.cms.gov/provider-data):

| File | Description | Rows |
|---|---|---|
| `Hospital_General_Information.csv` | Hospital metadata: location, type, ownership | 5,432 |
| `Complications_and_Deaths-Hospital.csv` | Quality measures by hospital and condition | 95,840 |

> Data files are excluded from this repo (see `.gitignore`). Download instructions below.

---

## Setup

```bash
git clone https://github.com/KelyNorel/provider-quality-sql.git
cd provider-quality-sql
pyenv virtualenv 3.11 provider-quality-sql
pyenv local provider-quality-sql
pip install -r requirements.txt
```

### Download the data manually

1. Go to https://data.cms.gov/provider-data/dataset/xubh-q36u → Download CSV → save as `data/raw/hospitals.csv`
2. Go to https://data.cms.gov/provider-data/dataset/ynj2-r877 → Download CSV → save as `data/raw/complications.csv`

---

## Analysis

All analysis is in `notebooks/01_explore.ipynb` using DuckDB (SQL-first, Snowflake-compatible syntax).

### Key Findings

**Finding 1 — Heart Attack Mortality Outliers**
Only 13 hospitals (0.3%) perform statistically worse than the national average 
for 30-day heart attack mortality. Huntsville Hospital (AL) has the highest 
rate at 17.1% vs ~13% national average.

**Finding 2 — Composite Quality Ranking**
Across 5 mortality measures, NYU Langone ranks #1 nationally (avg 6.96%), 
followed by VA San Diego (7.55%) and Brigham and Women's Faulkner (8.28%). 
Top performers show 4-6 fewer deaths per 100 patients vs the national benchmark.

**Finding 3 — State Rankings (Weighted by Volume)**
Massachusetts ranks #1 (weighted avg 11.46%), followed by Minnesota and New York. 
Weighting by patient volume meaningfully changes rankings — NJ drops from #3 to #10 
when volume is accounted for.

**Finding 4 — Ownership Type vs Quality**
Veterans Health Administration hospitals rank #1 by ownership type (9.46% mortality), 
outperforming all private and nonprofit systems. For-profit hospitals (13.21%) 
perform above the national average. Groups with fewer than 40 hospitals excluded 
from comparison.

---

## SQL Concepts Covered

- `JOIN` across multiple tables
- CTEs (`WITH ... AS`)
- Window functions (`RANK() OVER()`, `SUM() OVER()`)
- Weighted averages (`SUM(score * denominator) / SUM(denominator)`)
- `HAVING` vs `WHERE`
- `CAST` for type conversion
- Filtering and aggregation on real clinical data

---

## Stack

- **DuckDB** — SQL engine (Snowflake-compatible syntax)
- **Python / pandas** — data loading and display
- **Jupyter** — notebook environment

---

## Project Structure

```
provider-quality-sql/
├── data/
│   ├── raw/          # CMS source files (not tracked in git)
│   └── processed/    # DuckDB database file (not tracked in git)
├── notebooks/
│   └── 01_explore.ipynb   # Main analysis notebook
├── src/
│   └── queries.sql        # Final SQL queries (clean, no Python)
├── .gitignore
├── requirements.txt
└── README.md
```

---

## Author

Raquel (Kely) Norel, PhD — [LinkedIn](https://www.linkedin.com/in/raquel-norel) · [Google Scholar](https://scholar.google.com/citations?user=_7vMqI4AAAAJ&hl=en)