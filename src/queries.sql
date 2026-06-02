-- ============================================================
-- Provider Quality Analysis — CMS Hospital Data
-- Engine: DuckDB (Snowflake-compatible syntax)
-- Author: Raquel (Kely) Norel, PhD
-- ============================================================


-- ------------------------------------------------------------
-- 1. Heart attack mortality outliers
--    Hospitals performing worse than the national rate
-- ------------------------------------------------------------
SELECT 
    c."Facility ID",
    c."Facility Name",
    h."State",
    h."Hospital Type",
    c."Score",
    c."Denominator"
FROM complications c
JOIN hospitals h ON c."Facility ID" = h."Facility ID"
WHERE c."Measure ID" = 'MORT_30_AMI'
  AND c."Compared to National" = 'Worse Than the National Rate'
ORDER BY CAST(c."Score" AS FLOAT) DESC;


-- ------------------------------------------------------------
-- 2. Composite quality score per hospital
--    Weighted average across 5 mortality measures
--    Requires at least 4 measures to be eligible
-- ------------------------------------------------------------
WITH mortality_measures AS (
    SELECT 
        c."Facility ID",
        c."Facility Name",
        h."State",
        c."Measure ID",
        CAST(c."Score" AS FLOAT)         AS score,
        CAST(c."Denominator" AS INTEGER)  AS denominator
    FROM complications c
    JOIN hospitals h ON c."Facility ID" = h."Facility ID"
    WHERE c."Measure ID" IN ('MORT_30_AMI', 'MORT_30_HF', 'MORT_30_PN', 
                              'MORT_30_STK', 'MORT_30_COPD')
      AND c."Score" NOT IN ('Not Available', 'Not Applicable')
      AND c."Denominator" NOT IN ('Not Available', 'Not Applicable')
),
hospital_scores AS (
    SELECT
        "Facility ID",
        "Facility Name",
        "State",
        COUNT(DISTINCT "Measure ID")                                      AS measures_available,
        ROUND(SUM(score * denominator) / SUM(denominator), 2)            AS weighted_avg_mortality,
        ROUND(MIN(score), 2)                                              AS best_measure,
        ROUND(MAX(score), 2)                                              AS worst_measure,
        SUM(denominator)                                                  AS total_patients
    FROM mortality_measures
    GROUP BY "Facility ID", "Facility Name", "State"
    HAVING COUNT(DISTINCT "Measure ID") >= 4
)
SELECT 
    *,
    RANK() OVER (ORDER BY weighted_avg_mortality ASC) AS quality_rank
FROM hospital_scores
ORDER BY quality_rank
LIMIT 20;


-- ------------------------------------------------------------
-- 3. State-level quality ranking
--    Weighted by patient volume, min 10 hospitals
-- ------------------------------------------------------------
WITH mortality_measures AS (
    SELECT 
        c."Facility ID",
        h."State",
        CAST(c."Score" AS FLOAT)         AS score,
        CAST(c."Denominator" AS INTEGER)  AS denominator
    FROM complications c
    JOIN hospitals h ON c."Facility ID" = h."Facility ID"
    WHERE c."Measure ID" IN ('MORT_30_AMI', 'MORT_30_HF', 'MORT_30_PN', 
                              'MORT_30_STK', 'MORT_30_COPD')
      AND c."Score" NOT IN ('Not Available', 'Not Applicable')
      AND c."Denominator" NOT IN ('Not Available', 'Not Applicable')
)
SELECT
    "State",
    COUNT(DISTINCT "Facility ID")                                     AS num_hospitals,
    ROUND(SUM(score * denominator) / SUM(denominator), 2)            AS weighted_avg_mortality,
    ROUND(MIN(score), 2)                                              AS best_hospital_score,
    ROUND(MAX(score), 2)                                              AS worst_hospital_score,
    RANK() OVER (ORDER BY SUM(score * denominator) / SUM(denominator) ASC) AS state_rank
FROM mortality_measures
GROUP BY "State"
HAVING COUNT(DISTINCT "Facility ID") >= 10
ORDER BY state_rank;


-- ------------------------------------------------------------
-- 4. Ownership type vs quality
--    Min 40 hospitals for statistical reliability
-- ------------------------------------------------------------
WITH mortality_measures AS (
    SELECT 
        c."Facility ID",
        h."Hospital Ownership",
        CAST(c."Score" AS FLOAT)         AS score,
        CAST(c."Denominator" AS INTEGER)  AS denominator
    FROM complications c
    JOIN hospitals h ON c."Facility ID" = h."Facility ID"
    WHERE c."Measure ID" IN ('MORT_30_AMI', 'MORT_30_HF', 'MORT_30_PN', 
                              'MORT_30_STK', 'MORT_30_COPD')
      AND c."Score" NOT IN ('Not Available', 'Not Applicable')
      AND c."Denominator" NOT IN ('Not Available', 'Not Applicable')
)
SELECT
    "Hospital Ownership",
    COUNT(DISTINCT "Facility ID")                                     AS num_hospitals,
    ROUND(SUM(score * denominator) / SUM(denominator), 2)            AS weighted_avg_mortality,
    ROUND(MIN(score), 2)                                              AS best_score,
    ROUND(MAX(score), 2)                                              AS worst_score,
    RANK() OVER (ORDER BY SUM(score * denominator) / SUM(denominator) ASC) AS quality_rank
FROM mortality_measures
GROUP BY "Hospital Ownership"
HAVING COUNT(DISTINCT "Facility ID") >= 40
ORDER BY quality_rank;


-- ------------------------------------------------------------
-- 5. Provider recommendation engine
--    Top 5 hospitals for a given state and condition
--    Min 25 patients for statistical reliability
--    Replace :state and :condition with actual values
-- ------------------------------------------------------------
WITH eligible_hospitals AS (
    SELECT
        c."Facility ID",
        c."Facility Name",
        h."City/Town"                    AS city,
        h."State",
        h."Hospital Type",
        h."Hospital Ownership",
        c."Measure ID",
        c."Measure Name",
        CAST(c."Score" AS FLOAT)         AS score,
        CAST(c."Denominator" AS INTEGER)  AS denominator,
        c."Compared to National"
    FROM complications c
    JOIN hospitals h ON c."Facility ID" = h."Facility ID"
    WHERE h."State"      = 'NY'           -- replace with target state
      AND c."Measure ID" = 'MORT_30_AMI' -- replace with target condition
      AND c."Score"      NOT IN ('Not Available', 'Not Applicable')
      AND c."Denominator" NOT IN ('Not Available', 'Not Applicable')
      AND CAST(c."Denominator" AS INTEGER) >= 25
)
SELECT
    "Facility Name",
    city,
    "Hospital Type",
    "Hospital Ownership",
    "Measure Name",
    score                                           AS mortality_rate,
    denominator                                     AS patients_evaluated,
    "Compared to National",
    RANK() OVER (ORDER BY score ASC)                AS recommendation_rank
FROM eligible_hospitals
ORDER BY recommendation_rank
LIMIT 5;
-- ------------------------------------------------------------
-- 6. Distribution of hospital performance vs national rate
--    For a specific measure — uses SUM() OVER() window function
-- ------------------------------------------------------------
SELECT 
    "Compared to National",
    COUNT(*) AS num_hospitals,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 1) AS pct
FROM complications
WHERE "Measure ID" = 'MORT_30_AMI'
  AND "Compared to National" IS NOT NULL
GROUP BY "Compared to National"
ORDER BY num_hospitals DESC;


-- ------------------------------------------------------------
-- 7. Mortality rate by condition and ownership type
--    Grouped analysis across 5 conditions
-- ------------------------------------------------------------
SELECT 
    c."Measure ID",
    c."Measure Name",
    CASE 
        WHEN h."Hospital Ownership" LIKE '%Veterans%' THEN 'VA'
        WHEN h."Hospital Ownership" LIKE '%non-profit%' THEN 'Non-profit'
        WHEN h."Hospital Ownership" = 'Proprietary' THEN 'For-profit'
        ELSE 'Government'
    END AS ownership_group,
    ROUND(SUM(CAST(c."Score" AS FLOAT) * CAST(c."Denominator" AS INTEGER)) / 
          SUM(CAST(c."Denominator" AS INTEGER)), 2) AS weighted_avg_mortality,
    COUNT(DISTINCT c."Facility ID") AS num_hospitals
FROM complications c
JOIN hospitals h ON c."Facility ID" = h."Facility ID"
WHERE c."Measure ID" IN ('MORT_30_AMI', 'MORT_30_HF', 'MORT_30_PN', 
                          'MORT_30_STK', 'MORT_30_COPD')
  AND c."Score" NOT IN ('Not Available', 'Not Applicable')
  AND c."Denominator" NOT IN ('Not Available', 'Not Applicable')
GROUP BY c."Measure ID", c."Measure Name", ownership_group
ORDER BY c."Measure ID", weighted_avg_mortality ASC;


-- ------------------------------------------------------------
-- 8. National weighted average mortality
--    Across all 5 measures — used as benchmark throughout
-- ------------------------------------------------------------
SELECT 
    ROUND(SUM(CAST("Score" AS FLOAT) * CAST("Denominator" AS INTEGER)) / 
          SUM(CAST("Denominator" AS INTEGER)), 2) AS national_weighted_avg
FROM complications
WHERE "Measure ID" IN ('MORT_30_AMI', 'MORT_30_HF', 'MORT_30_PN', 
                        'MORT_30_STK', 'MORT_30_COPD')
  AND "Score" NOT IN ('Not Available', 'Not Applicable')
  AND "Denominator" NOT IN ('Not Available', 'Not Applicable');


-- ------------------------------------------------------------
-- 9. Eligible hospitals by state for a given condition
--    Used to contextualize recommendation rankings
-- ------------------------------------------------------------
SELECT 
    h."State",
    COUNT(DISTINCT c."Facility ID") AS total_hospitals,
    COUNT(DISTINCT CASE 
        WHEN c."Score" NOT IN ('Not Available', 'Not Applicable')
         AND CAST(c."Denominator" AS INTEGER) >= 25 
        THEN c."Facility ID" END)   AS eligible_hospitals
FROM complications c
JOIN hospitals h ON c."Facility ID" = h."Facility ID"
WHERE c."Measure ID" = 'MORT_30_HF' -- replace with target condition
GROUP BY h."State"
ORDER BY eligible_hospitals DESC;