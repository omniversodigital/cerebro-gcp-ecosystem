-- Market Performance View
-- Aggregated trading signal performance by symbol and source

CREATE OR REPLACE VIEW `cerebro_ecosystem.v_market_performance` AS
SELECT
  DATE(received_at) AS signal_date,
  symbol,
  source,
  COUNT(*) AS total_signals,
  COUNTIF(action = 'BUY') AS buy_signals,
  COUNTIF(action = 'SELL') AS sell_signals,
  COUNTIF(action = 'HOLD') AS hold_signals,
  COUNTIF(action = 'CLOSE') AS close_signals,
  ROUND(AVG(confidence), 4) AS avg_confidence,
  ROUND(MAX(confidence), 4) AS max_confidence,
  COUNTIF(confidence > 0.8) AS high_confidence_count,
  ROUND(COUNTIF(confidence > 0.8) / COUNT(*) * 100, 2) AS high_confidence_pct
FROM
  `cerebro_ecosystem.market_signals`
GROUP BY
  signal_date, symbol, source
ORDER BY
  signal_date DESC, total_signals DESC;
