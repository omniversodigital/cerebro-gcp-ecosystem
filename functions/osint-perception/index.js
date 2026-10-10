const functions = require('@google-cloud/functions-framework');
const { PubSub } = require('@google-cloud/pubsub');
const axios = require('axios');

const pubsub = new PubSub();
const TOPIC_NAME = 'market-signals';

// Environment parameters
const MODEL_ROUTER_URL = process.env.MODEL_ROUTER_URL || 'https://cerebro-model-router-1059051358117.us-central1.run.app';

functions.cloudEvent('gatherPerception', async (cloudEvent) => {
  console.log('[OSINT-PERCEPTION] Waking up to gather market context...');

  try {
    // 1. Ingestion Layer: Fetch real-time market data
    const cgResponse = await axios.get('https://api.coingecko.com/api/v3/simple/price?ids=bitcoin,ethereum&vs_currencies=usd&include_24hr_change=true&include_24hr_vol=true');
    const btcData = cgResponse.data.bitcoin;
    const ethData = cgResponse.data.ethereum;

    console.log('[OSINT-PERCEPTION] Raw Data:', JSON.stringify(cgResponse.data));

    // 2. Reasoning Layer: Ask Fable-5 to evaluate the market state
    const prompt = `Act as an elite quantitative analyst.
Market Data:
BTC: $${btcData.usd} (24h Change: ${btcData.usd_24h_change.toFixed(2)}%, 24h Vol: $${btcData.usd_24h_vol})
ETH: $${ethData.usd} (24h Change: ${ethData.usd_24h_change.toFixed(2)}%, 24h Vol: $${ethData.usd_24h_vol})

Evaluate this data and output a JSON response containing ONLY:
{"asset": "BTC/USD", "volatility": [number 0-1 based on 24h change magnitude], "confidence": [number 0-1 based on trend clarity and volume support]}`;

    let reasoningResult;
    try {
      const modelRes = await axios.post(`${MODEL_ROUTER_URL}/api/v1/inference`, {
        model: 'fable-5',
        prompt: prompt
      });
      
      const rawText = modelRes.data.response;
      // Extract JSON from markdown
      const jsonStr = rawText.match(/\{[\s\S]*\}/)[0];
      reasoningResult = JSON.parse(jsonStr);
      console.log('[OSINT-PERCEPTION] Fable-5 Reasoning:', reasoningResult);

    } catch (modelErr) {
      console.warn('[OSINT-PERCEPTION] Fable-5 unavailable or failed. Using fallback heuristic.', modelErr.message);
      const vol = Math.min(Math.abs(btcData.usd_24h_change) / 10, 1);
      reasoningResult = {
        asset: "BTC/USD",
        volatility: vol,
        confidence: vol > 0.5 ? 0.9 : 0.6 // Mock heuristic
      };
    }

    // 3. Execution/Orchestration Layer: Push to Market Signals
    const payload = {
      asset: reasoningResult.asset || "BTC/USD",
      volatility: reasoningResult.volatility,
      confidence: reasoningResult.confidence,
      timestamp: new Date().toISOString(),
      price: btcData.usd
    };

    const dataBuffer = Buffer.from(JSON.stringify(payload));
    const messageId = await pubsub.topic(TOPIC_NAME).publishMessage({ data: dataBuffer });

    console.log(`[OSINT-PERCEPTION] Successfully published reasoning to ${TOPIC_NAME}. MessageID: ${messageId}`);

  } catch (error) {
    console.error('[OSINT-PERCEPTION] Critical failure during perception cycle:', error);
    throw error;
  }
});
