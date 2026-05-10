-- =====================================================
-- 05_cohort.sql
-- Cohort Retention Analysis — Rees46 eCommerce Q4 2019
-- Purpose: Weekly purchase cohort retention matrix
-- Author: Mert Dal
-- =====================================================

-- Design decisions:
-- 1. Weekly cohorts chosen over monthly — 3 months of data
--    gives only 3 monthly retention points vs 13 weekly cohorts
--    with up to 13 retention data points each
-- 2. First purchase defines cohort — measures loyalty from
--    the moment of acquisition
-- 3. Pivoted format (w0-w13 columns) maps directly to
--    Power BI matrix heatmap visual
-- 4. NULLIF prevents division by zero for empty cohorts
-- 5. W0 hardcoded as 100.0 — always the baseline


CREATE OR REPLACE VIEW `project.Product_Analytics.vw_cohort` AS

WITH first_purchase AS (
  SELECT
    user_id,
    DATE_TRUNC(MIN(DATE(event_time)), WEEK(MONDAY)) AS cohort_week
  FROM `project.Product_Analytics.vw_clean_events`
  WHERE event_type = 'purchase'
  GROUP BY user_id
),

user_purchases AS (
  SELECT
    e.user_id,
    DATE_TRUNC(DATE(e.event_time), WEEK(MONDAY)) AS purchase_week
  FROM `project.Product_Analytics.vw_clean_events` e
  WHERE e.event_type = 'purchase'
  GROUP BY e.user_id, DATE_TRUNC(DATE(e.event_time), WEEK(MONDAY))
),

cohort_activity AS (
  SELECT
    f.cohort_week,
    DATE_DIFF(p.purchase_week, f.cohort_week, WEEK) AS week_number,
    COUNT(DISTINCT p.user_id)                        AS active_users
  FROM first_purchase f
  JOIN user_purchases p ON f.user_id = p.user_id
  GROUP BY f.cohort_week, week_number
),

cohort_size AS (
  SELECT
    cohort_week,
    COUNT(DISTINCT user_id) AS cohort_users
  FROM first_purchase
  GROUP BY cohort_week
)

SELECT
  s.cohort_week,
  s.cohort_users,
  100.0 AS w0,
  ROUND(MAX(CASE WHEN a.week_number = 1  THEN a.active_users * 100.0 / NULLIF(s.cohort_users, 0) END), 2) AS w1,
  ROUND(MAX(CASE WHEN a.week_number = 2  THEN a.active_users * 100.0 / NULLIF(s.cohort_users, 0) END), 2) AS w2,
  ROUND(MAX(CASE WHEN a.week_number = 3  THEN a.active_users * 100.0 / NULLIF(s.cohort_users, 0) END), 2) AS w3,
  ROUND(MAX(CASE WHEN a.week_number = 4  THEN a.active_users * 100.0 / NULLIF(s.cohort_users, 0) END), 2) AS w4,
  ROUND(MAX(CASE WHEN a.week_number = 5  THEN a.active_users * 100.0 / NULLIF(s.cohort_users, 0) END), 2) AS w5,
  ROUND(MAX(CASE WHEN a.week_number = 6  THEN a.active_users * 100.0 / NULLIF(s.cohort_users, 0) END), 2) AS w6,
  ROUND(MAX(CASE WHEN a.week_number = 7  THEN a.active_users * 100.0 / NULLIF(s.cohort_users, 0) END), 2) AS w7,
  ROUND(MAX(CASE WHEN a.week_number = 8  THEN a.active_users * 100.0 / NULLIF(s.cohort_users, 0) END), 2) AS w8,
  ROUND(MAX(CASE WHEN a.week_number = 9  THEN a.active_users * 100.0 / NULLIF(s.cohort_users, 0) END), 2) AS w9,
  ROUND(MAX(CASE WHEN a.week_number = 10 THEN a.active_users * 100.0 / NULLIF(s.cohort_users, 0) END), 2) AS w10,
  ROUND(MAX(CASE WHEN a.week_number = 11 THEN a.active_users * 100.0 / NULLIF(s.cohort_users, 0) END), 2) AS w11,
  ROUND(MAX(CASE WHEN a.week_number = 12 THEN a.active_users * 100.0 / NULLIF(s.cohort_users, 0) END), 2) AS w12,
  ROUND(MAX(CASE WHEN a.week_number = 13 THEN a.active_users * 100.0 / NULLIF(s.cohort_users, 0) END), 2) AS w13
FROM cohort_size s
LEFT JOIN cohort_activity a ON s.cohort_week = a.cohort_week
GROUP BY s.cohort_week, s.cohort_users
ORDER BY s.cohort_week;


-- =====================================================
-- Validation query
-- =====================================================

SELECT *
FROM `project.Product_Analytics.vw_cohort`
ORDER BY cohort_week;
