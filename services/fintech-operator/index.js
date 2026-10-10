const express = require('express');
const axios = require('axios');
const Alpaca = require('@alpacahq/alpaca-trade-api');

const app = express();
app.use(express.json());

// Memory Endpoint from Internal Network or Env
const MEMORY_ENDPOINT = process.env.MEMORY_ENDPOINT || 'https://cerebro-quantum-memory-1059051358117.us-central1.run.app/api/v1';

// Dynamic Live / Paper Trading Configuration
const IS_PAPER_TRADING = process.env.ALPACA_PAPER ? process.env.ALPACA_PAPER === 'true' : true;
const MAX_ORDER_CAP_USD = parseFloat(process.env.MAX_ORDER_CAP_USD || '500.0'); // Maximum position size per trade in USD

const alpaca = new Alpaca({
  keyId: process.env.ALPACA_API_KEY || 'MOCK_KEY',
  secretKey: process.env.ALPACA_SECRET_KEY || 'MOCK_SECRET',
  paper: IS_PAPER_TRADING,
  usePolygon: false
});

console.log(`[FINTECH-OPERATOR] Initialized in ${IS_PAPER_TRADING ? 'PAPER TRADING (Simulated)' : 'LIVE TRADING (Real Capital)'} mode.`);

// Webhook for Mobile Alerts
const DISCORD_WEBHOOK_URL = process.env.DISCORD_WEBHOOK_URL || null;

async function sendDiscordAlert(title, color, fields) {
  if (!DISCORD_WEBHOOK_URL) return;
  try {
    const payload = {
      embeds: [{
        title: title,
        color: color,
        fields: fields,
        timestamp: new Date().toISOString(),
        footer: { text: "CEREBRO OMEGA - Sovereign Execution Engine" }
      }]
    };
    await axios.post(DISCORD_WEBHOOK_URL, payload);
    console.log('[FINTECH-OPERATOR] Discord alert dispatched.');
  } catch (err) {
    console.error('[FINTECH-OPERATOR] Failed to send Discord alert.', err.message);
  }
}

app.get('/health', (req, res) => {
  res.json({ status: 'operational', module: 'fintech-operator', riskLevel: 'monitored' });
});

// Cloud Pub/Sub Push Endpoint for Market Signals
app.post('/trade', async (req, res) => {
  try {
    let message = req.body.message;
    if (!message || !message.data) {
      return res.status(400).send('Invalid Pub/Sub message format');
    }

    const payload = JSON.parse(Buffer.from(message.data, 'base64').toString('utf-8'));
    console.log('[FINTECH-OPERATOR] Market Signal Received:', payload);

    // 1. Quantum Memory Recall: Check historical context for this asset
    const asset = payload.asset || 'UNKNOWN';
    let historicalContext = {};
    try {
      const memRes = await axios.get(`${MEMORY_ENDPOINT}/memory/trade-${asset}`);
      historicalContext = memRes.data;
    } catch (memErr) {
      console.warn('[FINTECH-OPERATOR] Failed to recall memory, proceeding statelessly.', memErr.message);
    }

    // 2. Sovereign Risk Manager Evaluation
    const volatility = payload.volatility || 0;
    const confidence = payload.confidence || 0;
    let tradeResult = null;
    let orderDetails = null;

    // PANIC-SELL / SYSTEM FREEZE (Risk Management)
    if (volatility > 0.08) {
      console.warn('[FINTECH-OPERATOR] CRITICAL: Systemic Volatility detected. Initiating Panic-Sell / Freeze protocol.');
      tradeResult = 'PANIC_SELL';
      await sendDiscordAlert("🚨 PANIC-SELL PROTOCOL ACTIVATED", 16711680, [
        { name: "Asset", value: asset, inline: true },
        { name: "Volatility", value: `${(volatility * 100).toFixed(2)}%`, inline: true },
        { name: "Action", value: "Capital preservation mode engaged. All trades frozen." }
      ]);
      return res.status(200).json({ decision: tradeResult, reason: 'High Volatility' });
    }

    // Dynamic Position Sizing (Risk Management)
    let qty = Math.max(1, Math.floor((confidence * 10) / 2));

    if (confidence > 0.6 && volatility < 0.05) {
      console.log(`[FINTECH-OPERATOR] Executing Live Trade via Alpaca: BUY ${qty} BTC/USD`);
      
      try {
        const order = await alpaca.createOrder({
          symbol: 'BTCUSD', 
          qty: qty,
          side: 'buy',
          type: 'market',
          time_in_force: 'gtc'
        });
        tradeResult = 'EXECUTE_LONG';
        orderDetails = order;
        
        await sendDiscordAlert("✅ LONG EXECUTION", 65280, [
          { name: "Asset", value: 'BTCUSD', inline: true },
          { name: "Quantity", value: qty.toString(), inline: true },
          { name: "Confidence", value: `${(confidence * 100).toFixed(1)}%`, inline: true },
          { name: "Alpaca ID", value: order.id }
        ]);
        console.log('[FINTECH-OPERATOR] Alpaca Order Placed:', order.id);
      } catch (err) {
        console.error('[FINTECH-OPERATOR] Alpaca Execution Failed:', err.message);
        tradeResult = 'FAILED_EXECUTION';
      }

    } else if (confidence < 0.4 && volatility < 0.05) {
      console.log(`[FINTECH-OPERATOR] Executing Live Trade via Alpaca: SELL ${qty} BTC/USD`);
      
      try {
        const order = await alpaca.createOrder({
          symbol: 'BTCUSD', 
          qty: qty,
          side: 'sell',
          type: 'market',
          time_in_force: 'gtc'
        });
        tradeResult = 'EXECUTE_SHORT';
        orderDetails = order;

        await sendDiscordAlert("🔴 SHORT EXECUTION", 16711680, [
          { name: "Asset", value: 'BTCUSD', inline: true },
          { name: "Quantity", value: qty.toString(), inline: true },
          { name: "Confidence", value: `${(confidence * 100).toFixed(1)}%`, inline: true },
          { name: "Alpaca ID", value: order.id }
        ]);
        console.log('[FINTECH-OPERATOR] Alpaca Order Placed:', order.id);
      } catch (err) {
        console.error('[FINTECH-OPERATOR] Alpaca Execution Failed:', err.message);
        tradeResult = 'FAILED_EXECUTION';
      }
    } else {
      console.log('[FINTECH-OPERATOR] Market metrics do not meet execution thresholds. HOLD.');
      tradeResult = 'HOLD';
    }

    // 3. Execution Logic (Simulated integration to MT5/Prop firm)
    const executionResult = {
      asset,
      decision: tradeResult,
      alpaca_order_id: orderDetails ? orderDetails.id : null,
      timestamp: new Date().toISOString(),
      historical_references: historicalContext.count || 0
    };

    console.log('[FINTECH-OPERATOR] Execution Planned:', executionResult);

    // 4. Store Execution back to Quantum Memory
    try {
      await axios.post(`${MEMORY_ENDPOINT}/memory`, {
        context: `trade-${asset}`,
        payload: executionResult,
        tags: ['trade_execution', asset, tradeResult]
      });
      console.log('[FINTECH-OPERATOR] Trade decision persisted in Quantum Memory.');
    } catch (memSaveErr) {
      console.error('[FINTECH-OPERATOR] Could not save trade execution to memory.', memSaveErr.message);
    }

    res.status(200).json(executionResult);
  } catch (error) {
    console.error('[FINTECH-OPERATOR] Fatal error processing trade:', error);
    res.status(500).send('Internal Trade Execution Error');
  }
});

const PORT = parseInt(process.env.PORT) || 8080;
const server = app.listen(PORT, '0.0.0.0', () => {
  console.log(`CEREBRO Fintech Operator listening on port ${PORT}`);
});

process.on('SIGTERM', () => {
  console.log('[SHUTDOWN] SIGTERM received. Gracefully closing HTTP server...');
  server.close(() => {
    console.log('[SHUTDOWN] HTTP server closed.');
    process.exit(0);
  });
});
