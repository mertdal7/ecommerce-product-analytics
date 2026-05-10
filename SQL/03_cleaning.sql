-- =====================================================
-- 03_cleaning.sql
-- Cleaning View — Rees46 eCommerce Q4 2019
-- Purpose: Deduplicate and enrich raw_events
-- Author: Mert Dal
-- =====================================================

-- Design decisions:
-- 1. ROW_NUMBER() deduplication — cart events had up to 78
--    identical rows at the same timestamp (frontend tracking bug)
--    Keeps one row per unique event_time + event_type + user_id
--    + user_session + product_id combination
-- 2. category_top extracted from dot-separated category_code
--    e.g. electronics.smartphone → electronics
-- 3. brand normalized to lowercase — mixed casing in raw data
-- 4. Nulls filled with 'unknown' for brand and category_code
--    preserving full row count rather than dropping 32% of data
-- 5. price_bucket created for price sensitivity analysis
-- 6. Time dimensions extracted to avoid repeated computation
--    in downstream analytical views


CREATE OR REPLACE VIEW `project.Product_Analytics.vw_clean_events` AS

WITH deduplicated AS (
  SELECT
    *,
    ROW_NUMBER() OVER (
      PARTITION BY
        event_time,
        event_type,
        user_id,
        user_session,
        product_id
      ORDER BY event_time
    ) AS row_num
  FROM `project.Product_Analytics.raw_events`
  WHERE
    event_time IS NOT NULL
    AND event_type IS NOT NULL
    AND user_id    IS NOT NULL
    AND product_id IS NOT NULL
    AND event_type IN ('view', 'cart', 'purchase')
)

SELECT
  -- Time dimensions
  event_time,
  DATE(event_time)                    AS event_date,
  DATE_TRUNC(DATE(event_time), MONTH) AS event_month,
  EXTRACT(HOUR FROM event_time)       AS event_hour,
  FORMAT_DATE('%A', DATE(event_time)) AS event_day_of_week,

  -- Event
  event_type,

  -- User
  user_id,
  user_session,

  -- Product
  product_id,
  category_id,

  -- Category — null filled, top level extracted
  COALESCE(category_code, 'unknown')                 AS category_code,
  COALESCE(
    SPLIT(category_code, '.')[SAFE_OFFSET(0)],
    'unknown')                                        AS category_top,

  -- Brand — lowercased, null filled
  COALESCE(LOWER(brand), 'unknown')                  AS brand,

  -- Price
  price,

  -- Price bucket for segmentation analysis
  CASE
    WHEN price IS NULL THEN 'unknown'
    WHEN price < 50    THEN '0-50'
    WHEN price < 200   THEN '50-200'
    WHEN price < 500   THEN '200-500'
    WHEN price < 1000  THEN '500-1000'
    ELSE                    '1000+'
  END AS price_bucket

FROM deduplicated
WHERE row_num = 1
