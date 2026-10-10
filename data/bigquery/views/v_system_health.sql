-- System Health View
-- Combined view of ecosystem health across all domains

CREATE OR REPLACE VIEW `cerebro_ecosystem.v_system_health` AS
WITH skill_health AS (
  SELECT
    'skills' AS domain,
    COUNT(*) AS total_events_24h,
    COUNTIF(status = 'FAILED') AS failures_24h,
    ROUND(COUNTIF(status = 'SUCCESS') / NULLIF(COUNT(*), 0) * 100, 2) AS success_rate,
    ROUND(AVG(duration_ms), 0) AS avg_latency_ms
  FROM `cerebro_ecosystem.skill_executions`
  WHERE received_at > TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 24 HOUR)
),
market_health AS (
  SELECT
    'market' AS domain,
    COUNT(*) AS total_events_24h,
    0 AS failures_24h,
    100.0 AS success_rate,
    0 AS avg_latency_ms
  FROM `cerebro_ecosystem.market_signals`
  WHERE received_at > TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 24 HOUR)
),
security_health AS (
  SELECT
    'security' AS domain,
    COUNT(*) AS total_events_24h,
    COUNTIF(severity IN ('CRITICAL', 'HIGH')) AS failures_24h,
    ROUND((1 - COUNTIF(severity = 'CRITICAL') / NULLIF(COUNT(*), 0)) * 100, 2) AS success_rate,
    0 AS avg_latency_ms
  FROM `cerebro_ecosystem.security_events`
  WHERE received_at > TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 24 HOUR)
),
ai_health AS (
  SELECT
    'ai' AS domain,
    COUNT(*) AS total_events_24h,
    0 AS failures_24h,
    100.0 AS success_rate,
    ROUND(AVG(latency_ms), 0) AS avg_latency_ms
  FROM `cerebro_ecosystem.ai_interactions`
  WHERE recorded_at > TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 24 HOUR)
)
SELECT * FROM skill_health
UNION ALL
SELECT * FROM market_health
UNION ALL
SELECT * FROM security_health
UNION ALL
SELECT * FROM ai_health;
