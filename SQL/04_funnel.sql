-- =====================================================
-- 04_funnel.sql
-- Funnel Analysis — Rees46 eCommerce Q4 2019
-- Purpose: User-level purchase funnel with category CVR
-- Author: Mert Dal
-- =====================================================

-- Design decisions:
-- 1. User-level not event-level — avoids inflation from users
--    viewing the same product multiple times
-- 2. Q4 overall scope — per-month funnel caused >100%
--    cart-to-purchase rates due to cross-month journeys
--    (users who carted in Oct but purchased in Nov)
-- 3. Category CVR calculated separately at view level only
--    to avoid cross-category purchase mismatches
-- 4. Three row_types in one view — Q4_OVERALL, MONTHLY_TREND,
--    CATEGORY_CVR — each feeds a different Power BI visual


CREATE OR REPLACE VIEW `project.Product_Analytics.vw_funnel` AS

WITH user_funnel AS (
  -- Overall Q4 funnel per user — no month boundary issues
  SELECT
    user_id,
    MAX(CASE WHEN event_type = 'view'     THEN 1 ELSE 0 END) AS has_viewed,
    MAX(CASE WHEN event_type = 'cart'     THEN 1 ELSE 0 END) AS has_carted,
    MAX(CASE WHEN event_type = 'purchase' THEN 1 ELSE 0 END) AS has_purchased
  FROM `project.Product_Analytics.vw_clean_events`
  GROUP BY user_id
),

overall_funnel AS (
  -- Single Q4 funnel row — no monthly split
  SELECT
    SUM(has_viewed)    AS users_viewed,
    SUM(has_carted)    AS users_carted,
    SUM(has_purchased) AS users_purchased
  FROM user_funnel
),

monthly_events AS (
  -- Monthly event counts for trend line
  SELECT
    event_month,
    COUNT(*)                                                   AS total_events,
    COUNT(DISTINCT user_id)                                    AS unique_users,
    COUNT(DISTINCT CASE
      WHEN event_type = 'view'
      THEN user_id END)                                        AS monthly_viewers,
    COUNT(DISTINCT CASE
      WHEN event_type = 'purchase'
      THEN user_id END)                                        AS monthly_purchasers,
    ROUND(SUM(CASE
      WHEN event_type = 'purchase'
      THEN price ELSE 0 END), 2)                               AS monthly_revenue
  FROM `project.Product_Analytics.vw_clean_events`
  GROUP BY event_month
),

category_cvr AS (
  -- Category CVR across full Q4 — no month boundary
  SELECT
    category_top,
    COUNT(DISTINCT user_id)                                    AS viewers,
    COUNT(DISTINCT CASE
      WHEN event_type = 'purchase' THEN user_id END)           AS purchasers,
    ROUND(COUNT(DISTINCT CASE
      WHEN event_type = 'purchase' THEN user_id END)
      * 100.0 / NULLIF(COUNT(DISTINCT user_id), 0), 2)        AS category_cvr
  FROM `project.Product_Analytics.vw_clean_events`
  WHERE category_top != 'unknown'
  GROUP BY category_top
)

-- Part 1: Overall Q4 funnel (single row)
SELECT
  'Q4_OVERALL'                                                          AS row_type,
  NULL                                                                  AS event_month,
  NULL                                                                  AS category_top,
  f.users_viewed,
  f.users_carted,
  f.users_purchased,
  ROUND(f.users_carted    * 100.0 / NULLIF(f.users_viewed, 0), 2)      AS view_to_cart_rate,
  ROUND(f.users_purchased * 100.0 / NULLIF(f.users_carted, 0), 2)      AS cart_to_purchase_rate,
  ROUND(f.users_purchased * 100.0 / NULLIF(f.users_viewed, 0), 2)      AS overall_cvr,
  ROUND(100 - (f.users_carted    * 100.0 / NULLIF(f.users_viewed, 0)), 2) AS view_to_cart_dropoff,
  ROUND(100 - (f.users_purchased * 100.0 / NULLIF(f.users_carted, 0)), 2) AS cart_to_purchase_dropoff,
  NULL AS total_events,
  NULL AS unique_users,
  NULL AS monthly_viewers,
  NULL AS monthly_purchasers,
  NULL AS monthly_revenue,
  NULL AS viewers,
  NULL AS purchasers,
  NULL AS category_cvr
FROM overall_funnel f

UNION ALL

-- Part 2: Monthly event trends (3 rows — one per month)
SELECT
  'MONTHLY_TREND'  AS row_type,
  m.event_month,
  NULL             AS category_top,
  NULL AS users_viewed,
  NULL AS users_carted,
  NULL AS users_purchased,
  NULL AS view_to_cart_rate,
  NULL AS cart_to_purchase_rate,
  NULL AS overall_cvr,
  NULL AS view_to_cart_dropoff,
  NULL AS cart_to_purchase_dropoff,
  m.total_events,
  m.unique_users,
  m.monthly_viewers,
  m.monthly_purchasers,
  m.monthly_revenue,
  NULL AS viewers,
  NULL AS purchasers,
  NULL AS category_cvr
FROM monthly_events m

UNION ALL

-- Part 3: Category CVR breakdown
SELECT
  'CATEGORY_CVR'   AS row_type,
  NULL             AS event_month,
  c.category_top,
  NULL AS users_viewed,
  NULL AS users_carted,
  NULL AS users_purchased,
  NULL AS view_to_cart_rate,
  NULL AS cart_to_purchase_rate,
  NULL AS overall_cvr,
  NULL AS view_to_cart_dropoff,
  NULL AS cart_to_purchase_dropoff,
  NULL AS total_events,
  NULL AS unique_users,
  NULL AS monthly_viewers,
  NULL AS monthly_purchasers,
  NULL AS monthly_revenue,
  c.viewers,
  c.purchasers,
  c.category_cvr
FROM category_cvr c

ORDER BY row_type, event_month, category_top;


-- =====================================================
-- Validation queries
-- =====================================================

-- Check overall funnel — all rates must be between 0-100%
SELECT *
FROM `project.Product_Analytics.vw_funnel`
WHERE row_type = 'Q4_OVERALL';

-- Check monthly trend — 3 rows one per month
SELECT *
FROM `project.Product_Analytics.vw_funnel`
WHERE row_type = 'MONTHLY_TREND'
ORDER BY event_month;

-- Check category CVR — sorted by conversion rate
SELECT
  row_type,
  category_top,
  viewers,
  purchasers,
  category_cvr
FROM `project.Product_Analytics.vw_funnel`
WHERE row_type = 'CATEGORY_CVR'
ORDER BY category_cvr DESC;
