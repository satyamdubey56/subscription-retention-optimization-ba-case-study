-- ZestEats Subscription Retention — Cohort & Payment Analysis Queries
-- Fictional scenario / simulated schema (Redshift/Postgres-style)
-- Purpose: Track cohort retention over time and optimize payment retry sequence

-- Assumed schema:
--   subscribers(subscriber_id, signup_date, city, plan_type, status)
--   subscription_events(event_id, subscriber_id, event_type, event_date)
--   payment_attempts(attempt_id, subscriber_id, attempt_date, instrument_type, status)


-- ============================================================
-- Query 1: Cohort Retention Over 12 Months
-- Purpose: Track how different signup cohorts retain across
-- their first year to spot whether recent cohorts behave
-- differently from older ones (e.g. impact of a pricing change).
-- ============================================================
SELECT
    DATE_TRUNC('month', s.signup_date)                          AS signup_month,
    DATE_PART('month', AGE(se.event_date, s.signup_date))       AS months_since_signup,
    COUNT(DISTINCT s.subscriber_id)                             AS active_subscribers
FROM subscribers s
LEFT JOIN subscription_events se
    ON  se.subscriber_id = s.subscriber_id
    AND se.event_type    = 'renewed'
WHERE s.signup_date >= CURRENT_DATE - INTERVAL '12 months'
GROUP BY 1, 2
ORDER BY 1, 2;


-- ============================================================
-- Query 2: Payment Recovery Rate by Instrument Type
-- Purpose: Compare retry success across UPI vs. debit vs. credit
-- to determine the optimal ordering of the retry sequence.
-- If one instrument recovers significantly better on attempt 1,
-- it should be retried first — not just noted as an interesting finding.
-- ============================================================
SELECT
    instrument_type,
    COUNT(*)                                                                AS total_attempts,
    SUM(CASE WHEN status = 'success' THEN 1 ELSE 0 END)                   AS successful_attempts,
    ROUND(
        SUM(CASE WHEN status = 'success' THEN 1 ELSE 0 END)::DECIMAL
        / COUNT(*) * 100,
        1
    )                                                                       AS recovery_rate_pct
FROM payment_attempts
WHERE attempt_date >= CURRENT_DATE - INTERVAL '90 days'
GROUP BY instrument_type
ORDER BY recovery_rate_pct DESC;
