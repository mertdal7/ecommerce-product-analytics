-- =====================================================
-- 07_product.sql
-- Product Performance — Rees46 eCommerce Q4 2019
-- Purpose: Revenue, CVR and AOV by category, brand and price bucket
-- Author: Mert Dal
-- =====================================================

-- Design decisions:
-- 1. unknown brand and category filtered out — keeps analysis
--    clean and defensible (32% null category, 14% null brand)
-- 2. CVR calculated as purchasers / viewers using COUNT DISTINCT
--    on user_id — user-level not event-level conversion
-- 3. Grouped by event_month to enable monthly trend analysis
--    in Power BI with month slicer
-- 4. avg_order_value uses AVG on purchase events only
--    to reflect true transaction value


CREATE OR REPLACE VIEW `project.Product_Analytics.vw_product` AS

WITH product_events AS (
  SELECT
    event_month,
    product_id,
    category_top,
    brand,
    price,
    price_bucket,
    event_type,
    user_id
  FROM `project.Product_Analytics.vw_clean_events`
  WHERE category_top != 'unknown'
    AND brand        != 'unknown'
),

product_metrics AS (
  SELECT
    event_month,
    category_top,
    brand,
    price_bucket,
    COUNT(*)                                             AS total_events,
    COUNT(DISTINCT user_id)                              AS unique_users,
    COUNT(DISTINCT product_id)                           AS unique_products,
    COUNT(DISTINCT CASE
      WHEN event_type = 'view'
      THEN user_id END)                                  AS viewers,
    COUNT(DISTINCT CASE
      WHEN event_type = 'cart'
      THEN user_id END)                                  AS carters,
    COUNT(DISTINCT CASE
      WHEN event_type = 'purchase'
      THEN user_id END)                                  AS purchasers,
    ROUND(SUM(CASE
      WHEN event_type = 'purchase'
      THEN price ELSE 0 END), 2)                         AS revenue,
    ROUND(AVG(CASE
      WHEN event_type = 'purchase'
      THEN price END), 2)                                AS avg_order_value,
    ROUND(COUNT(DISTINCT CASE
      WHEN event_type = 'purchase' THEN user_id END)
      * 100.0 / NULLIF(COUNT(DISTINCT CASE
      WHEN event_type = 'view'    THEN user_id END), 0)
    , 2)                                                 AS cvr
  FROM product_events
  GROUP BY
    event_month,
    category_top,
    brand,
    price_bucket
)

SELECT
  event_month,
  category_top,
  brand,
  price_bucket,
  total_events,
  unique_users,
  unique_products,
  viewers,
  carters,
  purchasers,
  revenue,
  avg_order_value,
  cvr
FROM product_metrics
ORDER BY event_month, revenue DESC;


-- =====================================================
-- Validation queries
-- =====================================================

-- Check category level — revenue, CVR and brand count
SELECT
  category_top,
  SUM(revenue)          AS total_revenue,
  ROUND(AVG(cvr), 2)    AS avg_cvr,
  SUM(purchasers)       AS total_purchasers,
  COUNT(DISTINCT brand) AS unique_brands
FROM `project.Product_Analytics.vw_product`
GROUP BY category_top
ORDER BY total_revenue DESC
LIMIT 10;

-- Check monthly revenue trend — Dec should be highest
SELECT
  event_month,
  SUM(revenue)       AS monthly_revenue,
  SUM(purchasers)    AS monthly_purchasers,
  ROUND(AVG(cvr), 2) AS avg_cvr
FROM `project.Product_Analytics.vw_product`
GROUP BY event_month
ORDER BY event_month;

-- Cross-check electronics revenue against raw data
-- vw_product gap vs raw is expected due to unknown brand filter
SELECT
  event_month,
  SUM(revenue)          AS product_view_revenue,
  COUNT(DISTINCT brand) AS brands
FROM `project.Product_Analytics.vw_product`
WHERE category_top = 'electronics'
GROUP BY event_month
ORDER BY event_month;

SELECT
  DATE_TRUNC(event_time, MONTH) AS event_month,
  ROUND(SUM(price), 2)          AS raw_revenue,
  COUNT(DISTINCT user_id)       AS purchasers
FROM `project.Product_Analytics.vw_clean_events`
WHERE event_type   = 'purchase'
  AND category_top = 'electronics'
GROUP BY event_month
ORDER BY event_month;

-- December data completeness check
SELECT
  MIN(DATE(event_time)) AS first_day,
  MAX(DATE(event_time)) AS last_day,
  COUNT(*)              AS total_rows
FROM `project.Product_Analytics.raw_events`
WHERE DATE_TRUNC(DATE(event_time), MONTH) = '2019-12-01';
