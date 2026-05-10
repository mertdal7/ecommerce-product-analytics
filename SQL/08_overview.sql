-- =====================================================
-- 08_overview.sql
-- Overview & KPIs — Rees46 eCommerce Q4 2019
-- Purpose: Monthly KPIs, event breakdown and MoM deltas
-- Author: Mert Dal
-- =====================================================

-- Design decisions:
-- 1. Monthly granularity — 3 rows (Oct, Nov, Dec) feed
--    Power BI KPI cards and trend line simultaneously
-- 2. Event type breakdown pivoted into columns using MAX(CASE)
--    so Power BI can reference view_pct, cart_pct, purchase_pct
--    directly without additional DAX transformations
-- 3. MoM deltas calculated in SQL using LAG() window function
--    rather than DAX — keeps Power BI measures simple
-- 4. CVR calculated as purchasers / viewers (user-level)
--    consistent with vw_funnel methodology


CREATE OR REPLACE VIEW `project.Product_Analytics.vw_overview` AS

WITH monthly AS (
  SELECT
    event_month,
    COUNT(*)                                                   AS total_events,
    COUNT(DISTINCT user_id)                                    AS unique_users,
    COUNT(DISTINCT CASE
      WHEN event_type = 'view'     THEN user_id END)           AS viewers,
    COUNT(DISTINCT CASE
      WHEN event_type = 'cart'     THEN user_id END)           AS carters,
    COUNT(DISTINCT CASE
      WHEN event_type = 'purchase' THEN user_id END)           AS purchasers,
    ROUND(SUM(CASE
      WHEN event_type = 'purchase'
      THEN price ELSE 0 END), 2)                               AS revenue,
    ROUND(COUNT(DISTINCT CASE
      WHEN event_type = 'purchase' THEN user_id END) * 100.0
      / NULLIF(COUNT(DISTINCT CASE
      WHEN event_type = 'view'     THEN user_id END), 0), 2)  AS cvr
  FROM `project.Product_Analytics.vw_clean_events`
  GROUP BY event_month
),

event_breakdown AS (
  SELECT
    event_month,
    event_type,
    COUNT(*)                                             AS event_count,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER
      (PARTITION BY event_month), 2)                    AS event_pct
  FROM `project.Product_Analytics.vw_clean_events`
  GROUP BY event_month, event_type
)

SELECT
  m.event_month,
  m.total_events,
  m.unique_users,
  m.viewers,
  m.carters,
  m.purchasers,
  m.revenue,
  m.cvr,

  -- Event type breakdown
  MAX(CASE WHEN e.event_type = 'view'
    THEN e.event_count END)                              AS view_events,
  MAX(CASE WHEN e.event_type = 'cart'
    THEN e.event_count END)                              AS cart_events,
  MAX(CASE WHEN e.event_type = 'purchase'
    THEN e.event_count END)                              AS purchase_events,
  MAX(CASE WHEN e.event_type = 'view'
    THEN e.event_pct END)                                AS view_pct,
  MAX(CASE WHEN e.event_type = 'cart'
    THEN e.event_pct END)                                AS cart_pct,
  MAX(CASE WHEN e.event_type = 'purchase'
    THEN e.event_pct END)                                AS purchase_pct,

  -- Month over month deltas
  ROUND(m.revenue - LAG(m.revenue)
    OVER (ORDER BY m.event_month), 2)                    AS revenue_mom_delta,
  ROUND(m.unique_users - LAG(m.unique_users)
    OVER (ORDER BY m.event_month), 0)                    AS users_mom_delta,
  ROUND((m.revenue - LAG(m.revenue)
    OVER (ORDER BY m.event_month))
    * 100.0 / NULLIF(LAG(m.revenue)
    OVER (ORDER BY m.event_month), 0), 2)                AS revenue_mom_pct,
  ROUND((m.unique_users - LAG(m.unique_users)
    OVER (ORDER BY m.event_month))
    * 100.0 / NULLIF(LAG(m.unique_users)
    OVER (ORDER BY m.event_month), 0), 2)                AS users_mom_pct

FROM monthly m
LEFT JOIN event_breakdown e ON m.event_month = e.event_month
GROUP BY
  m.event_month,
  m.total_events,
  m.unique_users,
  m.viewers,
  m.carters,
  m.purchasers,
  m.revenue,
  m.cvr
ORDER BY m.event_month;
