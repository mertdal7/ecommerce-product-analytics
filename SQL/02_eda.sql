-- =====================================================
-- 02_eda.sql
-- Exploratory Data Analysis — Rees46 eCommerce Q4 2019
-- Purpose: Understand data structure before cleaning
-- Author: Mert Dal
-- =====================================================


-- 1. Basic shape
SELECT
  DATE_TRUNC(event_time, MONTH)  AS month,
  COUNT(*)                        AS total_rows,
  COUNT(DISTINCT user_id)         AS unique_users,
  COUNT(DISTINCT product_id)      AS unique_products,
  COUNT(DISTINCT event_type)      AS unique_event_types
FROM `project.Product_Analytics.raw_events`
GROUP BY 1
ORDER BY 1;

/*
month                   total_rows   unique_users   unique_products   unique_event_types
2019-10-01 00:00:00     42448764     3022290        137799            3
2019-11-01 00:00:00     67501979     3696117        176666            3
2019-12-01 00:00:00     67542878     4577232        180762            3
*/


-- 2. Event type distribution
-- Finding: only 3 event types exist — no remove_from_cart
-- view 94.89% / cart 3.60% / purchase 1.51%
SELECT
  event_type,
  COUNT(*)                                           AS total,
  ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER(), 2) AS pct
FROM `project.Product_Analytics.raw_events`
GROUP BY event_type
ORDER BY total DESC;

/*
event_type   total       pct
view         166909509   94.04
cart         6317151     3.56
purchase     4267059     2.40
*/


-- 3. Null analysis per column
-- Finding: brand 14% null, category_code 32% null
-- All critical fields (event_time, event_type, user_id) are clean
SELECT
  COUNTIF(event_time    IS NULL) AS null_event_time,
  COUNTIF(event_type    IS NULL) AS null_event_type,
  COUNTIF(user_id       IS NULL) AS null_user_id,
  COUNTIF(product_id    IS NULL) AS null_product_id,
  COUNTIF(price         IS NULL) AS null_price,
  COUNTIF(brand         IS NULL) AS null_brand,
  COUNTIF(category_code IS NULL) AS null_category_code
FROM `project.Product_Analytics.raw_events`;

/*
null_event_time   null_event_type   null_user_id   null_product_id   null_price   null_brand    null_category_code
0                 0                 0              0                 0            15331243      35413780
*/


-- 4. Category code structure
-- Finding: dot-separated hierarchy e.g. electronics.smartphone
-- Justifies SPLIT(category_code, '.') in cleaning script
SELECT
  category_code,
  COUNT(*) AS occurrences
FROM `project.Product_Analytics.raw_events`
WHERE category_code IS NOT NULL
GROUP BY category_code
ORDER BY occurrences DESC
LIMIT 20;

/*
category_code                        occurrences
electronics.smartphone               27882231
electronics.clocks                   3397999
electronics.video.tv                 3321796
computers.notebook                   3318177
electronics.audio.headphone          2917065
apparel.shoes                        2650791
appliances.environment.vacuum        2329728
appliances.kitchen.refrigerators     2314917
appliances.kitchen.washer            2273270
computers.desktop                    1114744
*/


-- 5. Category hierarchy depth
-- Finding: max 3 levels e.g. appliances.kitchen.washer
SELECT
  ARRAY_LENGTH(SPLIT(category_code, '.')) AS depth,
  COUNT(*)                                 AS occurrences
FROM `project.Product_Analytics.raw_events`
WHERE category_code IS NOT NULL
GROUP BY depth
ORDER BY depth;

/*
depth   occurrences
2       44143770
3       30293612
4       99581
*/


-- 6. Price distribution on purchase events
-- Finding: prices range $0.77 to $2,574 — justifies price buckets
SELECT
  MIN(price)                              AS min_price,
  MAX(price)                              AS max_price,
  ROUND(AVG(price), 2)                    AS avg_price,
  APPROX_QUANTILES(price, 4)[OFFSET(1)]  AS p25,
  APPROX_QUANTILES(price, 4)[OFFSET(2)]  AS median,
  APPROX_QUANTILES(price, 4)[OFFSET(3)]  AS p75,
  COUNTIF(price = 0)                      AS zero_price_rows,
  COUNTIF(price IS NULL)                  AS null_price_rows
FROM `project.Product_Analytics.raw_events`
WHERE event_type = 'purchase';

/*
min_price   max_price   avg_price   p25     median   p75      zero_price_rows   null_price_rows
0.77        2574.07     304.35      83.66   174.78   374.72   0                 0
*/


-- 7. Duplicate check — exact duplicates including timestamp
-- Finding: cart events duplicated up to 78x at identical timestamps
-- Confirmed as frontend tracking bug — not quantity data
-- All duplicates are cart events, timestamps identical to the millisecond
SELECT
  event_time,
  event_type,
  user_id,
  user_session,
  product_id,
  COUNT(*) AS occurrences
FROM `project.Product_Analytics.raw_events`
GROUP BY 1, 2, 3, 4, 5
HAVING COUNT(*) > 1
ORDER BY occurrences DESC
LIMIT 10;

/*
event_time                    event_type   user_id     user_session                           product_id   occurrences
2019-11-17 16:58:15 UTC       cart         518642416   77d81adc-098e-4ae7-b608-2b925aa236f2   1004836      78
2019-11-16 03:31:46 UTC       cart         515793237   824fb9af-2d7e-469a-ac90-ad262b3c460f   22700078     75
2019-11-14 18:52:55 UTC       cart         539470962   b3d5fef1-f1ba-442d-b181-b5b98db53c60   1004792      55
2019-11-17 16:19:49 UTC       cart         519255323   301334c2-6e57-47e6-bfe2-19c88e1d790a   26400280     51
2019-11-20 09:52:58 UTC       cart         539910091   57e8e1f8-f0e0-4c4b-81dd-abb6c5d57499   3700766      49
2019-11-14 12:11:22 UTC       cart         518744344   e9010176-4e46-443a-9ac0-1cd071a33d0e   28712567     47
2019-11-12 06:08:45 UTC       cart         547398157   296c5a71-4ee4-45e9-8b83-41ffa67c03f4   1004565      46
2019-11-15 10:14:23 UTC       cart         523760549   cda41e84-070a-4e83-9c3f-f58057665b72   1005160      42
2019-10-26 11:45:01 UTC       cart         560549276   709dbef3-2a94-4a20-8675-f72c8970a570   34500090     41
2019-11-15 12:10:38 UTC       cart         515212485   e589601a-8aa2-4abf-8637-bb3de90f8cb1   3600661      38
*/


-- 8. Duplicate investigation — drill into specific user
-- Finding: same product carted across multiple timestamps in short window
-- User has legitimate cart interactions across 7 distinct timestamps
-- but each timestamp contains up to 78 identical rows — confirms tracking bug
SELECT
  event_time,
  event_type,
  user_id,
  product_id,
  COUNT(*)             AS occurrences,
  MIN(price)           AS price_min,
  MAX(price)           AS price_max
FROM `project.Product_Analytics.raw_events`
WHERE user_id    = '518642416'
  AND product_id = '1004836'
  AND event_type = 'cart'
GROUP BY 1, 2, 3, 4
ORDER BY event_time;

/*
event_time                  event_type   user_id     product_id   occurrences   price_min   price_max
2019-11-17 16:53:21 UTC     cart         518642416   1004836      1             244.02      244.02
2019-11-17 16:58:13 UTC     cart         518642416   1004836      11            244.02      244.02
2019-11-17 16:58:14 UTC     cart         518642416   1004836      28            244.02      244.02
2019-11-17 16:58:15 UTC     cart         518642416   1004836      78            244.02      244.02
2019-11-17 16:58:16 UTC     cart         518642416   1004836      13            244.02      244.02
2019-11-17 16:58:19 UTC     cart         518642416   1004836      1             244.02      244.02
2019-11-17 16:58:40 UTC     cart         518642416   1004836      4             244.02      244.02
*/
