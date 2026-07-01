-- ZestEats Subscription Retention — Churn Analysis Queries
-- Fictional scenario / simulated schema (Redshift/Postgres-style)
-- Purpose: Understand churn drivers and identify at-risk subscribers

-- Assumed schema:
--   subscribers(subscriber_id, signup_date, city, plan_type, status)
--   orders(order_id, subscriber_id, order_date, order_value)
--   subscription_events(event_id, subscriber_id, event_type, event_date)
--   subscriber_risk_scores(subscriber_id, score_date, risk_score, risk_tier, reason_code)


-- ============================================================
-- Query 1: Churn Rate by Engagement Level
-- Purpose: Confirm whether low order frequency in the trailing
-- 30 days is associated with higher churn in the following 60 days.
-- ============================================================
WITH monthly_orders AS (
    SELECT
        subscriber_id,
        COUNT(*) AS orders_last_30d
    FROM orders
    WHERE order_date >= CURRENT_DATE - INTERVAL '30 days'
    GROUP BY subscriber_id
),
churn_flag AS (
    SELECT
        subscriber_id,
        MAX(CASE WHEN event_type = 'cancelled' THEN 1 ELSE 0 END) AS churned_next_60d
    FROM subscription_events
    WHERE event_date BETWEEN CURRENT_DATE AND CURRENT_DATE + INTERVAL '60 days'
    GROUP BY subscriber_id
)
SELECT
    CASE
        WHEN mo.orders_last_30d = 0       THEN '0 orders'
        WHEN mo.orders_last_30d BETWEEN 1 AND 3 THEN '1-3 orders'
        ELSE '4+ orders'
    END AS engagement_band,
    COUNT(*)                                                  AS subscriber_count,
    ROUND(AVG(COALESCE(cf.churned_next_60d, 0)) * 100, 1)   AS churn_rate_pct
FROM monthly_orders mo
LEFT JOIN churn_flag cf ON cf.subscriber_id = mo.subscriber_id
GROUP BY 1
ORDER BY churn_rate_pct DESC;


-- ============================================================
-- Query 2: High-Risk Subscriber List for CRM Outreach
-- Purpose: Pull today's at-risk subscribers with the attributes
-- needed to personalize an intervention attempt.
-- ============================================================
SELECT
    rs.subscriber_id,
    rs.risk_score,
    rs.reason_code,
    s.city,
    s.plan_type
FROM subscriber_risk_scores rs
JOIN subscribers s ON s.subscriber_id = rs.subscriber_id
WHERE rs.score_date  = CURRENT_DATE
  AND rs.risk_tier   = 'High'
  AND s.status       = 'active'
ORDER BY rs.risk_score DESC
LIMIT 500;
