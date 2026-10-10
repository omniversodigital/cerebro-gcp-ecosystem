import express from 'express';
import axios from 'axios';
import yahooFinance from 'yahoo-finance2';
import { PubSub } from '@google-cloud/pubsub';

const app = express();
app.use(express.json());

const pubsub = new PubSub();
const TOPIC_NAME = 'ecosystem-events';

// Algorithm parameters
const ASSETS_TO_TRACK = ['BTC-USD', 'SPY', 'QQQ', '^VIX'];

async function gatherIntelligence() {
  console.log('[OSINT] Gathering global market intelligence...');
  let totalVolatility = 0;
  let bullishSignals = 0;
  let assetsCount = 0;
  
  for (const asset of ASSETS_TO_TRACK) {
    try {
      const quote = await yahooFinance.quote(asset);
      const changePercent = quote.regularMarketChangePercent || 0;
      
      // Accumulate absolute volatility (VIX handled differently, just adding to systemic volatility)
      totalVolatility += Math.abs(changePercent / 100);
      assetsCount++;
      
      if (asset !== '^VIX') {
        if (changePercent > 0) bullishSignals++;
      } else {
        // VIX dropping is bullish for equities/crypto usually
        if (changePercent < 0) bullishSignals++;
      }
      
    } catch (err) {
      console.warn(`[OSINT] Failed to fetch data for ${asset}:`, err.message);
    }
  }

  // Artificial amplification for testing if volatility is too low
  const avgVolatility = assetsCount > 0 ? (totalVolatility / assetsCount) * 1.5 : 0;
  
  // Confidence is a ratio of bullish signals (0 to 1)
  const confidence = assetsCount > 0 ? (bullishSignals / assetsCount) : 0;

  return { volatility: avgVolatility, confidence };
}

app.post('/trigger', async (req, res) => {
  try {
    const intelligence = await gatherIntelligence();
    
    const payload = {
      asset: 'BTCUSD', // Targeted execution asset
      volatility: intelligence.volatility,
      confidence: intelligence.confidence,
      timestamp: new Date().toISOString()
    };

    console.log('[OSINT] Algorithm Computed Output:', payload);

    // Publish to ecosystem-events for the Fintech Operator
    const dataBuffer = Buffer.from(JSON.stringify(payload));
    const messageId = await pubsub.topic(TOPIC_NAME).publishMessage({ data: dataBuffer });

    console.log(`[OSINT] Published intelligence to ${TOPIC_NAME} (Message ID: ${messageId})`);
    
    res.status(200).json({ success: true, messageId, intelligence });
  } catch (error) {
    console.error('[OSINT] Fatal error computing intelligence:', error);
    res.status(500).send('Internal OSINT Error');
  }
});

const PORT = parseInt(process.env.PORT) || 8080;
app.listen(PORT, '0.0.0.0', () => {
  console.log(`CEREBRO OSINT Perception engine listening on port ${PORT}`);
});
