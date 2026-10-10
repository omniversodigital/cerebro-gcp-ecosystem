-- Daily Skill Usage View
-- Shows aggregated skill execution metrics per day

CREATE OR REPLACE VIEW `cerebro_ecosystem.v_daily_skill_usage` AS
SELECT
  DATE(received_at) AS execution_date,
  skill_name,
  COUNT(*) AS total_executions,
  COUNTIF(status = 'SUCCESS') AS successful,
  COUNTIF(status = 'FAILED') AS failed,
  COUNTIF(status = 'TIMEOUT') AS timeouts,
  ROUND(COUNTIF(status = 'SUCCESS') / COUNT(*) * 100, 2) AS success_rate_pct,
  ROUND(AVG(duration_ms), 0) AS avg_duration_ms,
  ROUND(APPROX_QUANTILES(duration_ms, 100)[OFFSET(95)], 0) AS p95_duration_ms,
  MIN(received_at) AS first_execution,
  MAX(received_at) AS last_execution,
  COUNT(DISTINCT source) AS unique_sources
FROM
  `cerebro_ecosystem.skill_executions`
GROUP BY
  execution_date, skill_name
ORDER BY
  execution_date DESC, total_executions DESC;
