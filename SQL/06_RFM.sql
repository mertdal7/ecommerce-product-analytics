-- =====================================================
-- 06_rfm.sql
-- RFM Segmentation — Rees46 eCommerce Q4 2019
-- Purpose: Score and segment users by purchase behavior
-- Author: Mert Dal
-- =====================================================

-- Design decisions:
-- 1. Reference date Jan 1 2020 — day after dataset ends
--    ensures Dec buyers get fair recency scores
-- 2. Frequency scored as binary (5 or 1) not NTILE(5)
--    80% of Q4 users purchased exactly once making NTILE
--    frequency buckets meaningless — scores 1-4 all mapped
--    to frequency = 1
-- 3. Recency NTILE ordered DESC — lower days = more recent
--    = higher score (score 5 = most recent buyers)
-- 4. 7 segments defined to reflect Q4 holiday behavior
--    including High Value New for recent high-spend first-timers


CREATE OR REPLACE VIEW `project.Product_Analytics.vw_rfm` AS

WITH purchase_data AS (
  SELECT
    user_id,
    event_time,
    price
  FROM `project.Product_Analytics.vw_clean_events`
  WHERE event_type = 'purchase'
),

rfm_raw AS (
  SELECT
    user_id,
    DATE_DIFF(DATE '2020-01-01', DATE(MAX(event_time)), DAY) AS recency_days,
    COUNT(DISTINCT DATE(event_time))                          AS frequency,
    ROUND(SUM(price), 2)                                      AS monetary
  FROM purchase_data
  GROUP BY user_id
),

rfm_scored AS (
  SELECT
    user_id,
    recency_days,
    frequency,
    monetary,
    -- Recency: lower days = more recent = higher score
    NTILE(5) OVER (ORDER BY recency_days DESC) AS r_score,
    -- Frequency: binary — 80% of users bought once in Q4
    CASE
      WHEN frequency >= 2 THEN 5
      ELSE 1
    END AS f_score,
    -- Monetary: higher spend = higher score
    NTILE(5) OVER (ORDER BY monetary ASC) AS m_score
  FROM rfm_raw
),

rfm_segmented AS (
  SELECT
    user_id,
    recency_days,
    frequency,
    monetary,
    r_score,
    f_score,
    m_score,
    CONCAT(
      CAST(r_score AS STRING),
      CAST(f_score AS STRING),
      CAST(m_score AS STRING)
    ) AS rfm_score,
    ROUND((r_score + f_score + m_score) / 3.0, 2) AS avg_rfm_score,
    CASE
      WHEN r_score >= 4 AND f_score = 5 AND m_score >= 4 THEN 'Champions'
      WHEN r_score >= 3 AND f_score = 5                  THEN 'Loyal'
      WHEN r_score >= 4 AND f_score = 1 AND m_score >= 4 THEN 'High Value New'
      WHEN r_score >= 4 AND f_score = 1                  THEN 'Promising'
      WHEN r_score <= 2 AND f_score = 5                  THEN 'At Risk'
      WHEN r_score <= 2 AND m_score >= 4                 THEN 'Hibernating'
      ELSE                                                    'Lost'
    END AS segment
  FROM rfm_scored
)

SELECT
  user_id,
  recency_days,
  frequency,
  monetary,
  r_score,
  f_score,
  m_score,
  rfm_score,
  avg_rfm_score,
  segment
FROM rfm_segmented
ORDER BY avg_rfm_score DESC;


-- =====================================================
-- Validation queries
-- =====================================================

-- Check r_score distribution — score 5 must be most recent
SELECT
  r_score,
  COUNT(*)                    AS users,
  ROUND(AVG(recency_days), 0) AS avg_recency_days,
  MIN(recency_days)           AS min_recency,
  MAX(recency_days)           AS max_recency
FROM `project.Product_Analytics.vw_rfm`
GROUP BY r_score
ORDER BY r_score DESC;

-- Check segment distribution — validate business logic
-- Champions must have lowest recency, Lost must have highest
SELECT
  segment,
  COUNT(*)                                         AS user_count,
  ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER(), 2) AS pct_of_users,
  ROUND(AVG(monetary), 2)                          AS avg_spend,
  ROUND(AVG(recency_days), 0)                      AS avg_recency_days,
  ROUND(AVG(frequency), 1)                         AS avg_frequency
FROM `project.Product_Analytics.vw_rfm`
GROUP BY segment
ORDER BY avg_recency_days ASC;
