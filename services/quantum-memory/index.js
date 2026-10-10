const express = require('express');
const { BigQuery } = require('@google-cloud/bigquery');

const app = express();
app.use(express.json({ limit: '10mb' }));

const bigquery = new BigQuery();
const datasetId = 'cerebro_ecosystem';
const tableId = 'quantum_memory';

// Ensure table exists on startup
async function initStorage() {
  try {
    const dataset = bigquery.dataset(datasetId);
    const [datasetExists] = await dataset.exists();
    if (!datasetExists) await dataset.create();

    const table = dataset.table(tableId);
    const [tableExists] = await table.exists();
    if (!tableExists) {
      const schema = [
        { name: 'memory_id', type: 'STRING', mode: 'REQUIRED' },
        { name: 'timestamp', type: 'TIMESTAMP', mode: 'REQUIRED' },
        { name: 'context', type: 'STRING', mode: 'REQUIRED' },
        { name: 'tags', type: 'STRING', mode: 'REPEATED' },
        { name: 'payload', type: 'JSON', mode: 'REQUIRED' }
      ];
      await table.create({ schema });
      console.log(`[STORAGE] Table ${tableId} created.`);
    } else {
      console.log(`[STORAGE] Table ${tableId} verified.`);
    }
  } catch (err) {
    console.error(`[STORAGE] Error initializing BigQuery:`, err);
  }
}

initStorage();

// ── Endpoints ──

app.get('/health', (req, res) => {
  res.json({ status: 'operational', service: 'cerebro-quantum-memory' });
});

// Store Memory
app.post('/api/v1/memory', async (req, res) => {
  const { context, payload, tags = [] } = req.body;

  if (!context || !payload) {
    return res.status(400).json({ error: 'context and payload are required' });
  }

  const memory_id = `mem-${Date.now()}-${Math.random().toString(36).substr(2, 9)}`;
  const timestamp = bigquery.datetime(new Date().toISOString());

  try {
    const row = {
      memory_id,
      timestamp,
      context,
      tags,
      payload: JSON.stringify(payload)
    };

    await bigquery.dataset(datasetId).table(tableId).insert([row]);
    res.status(201).json({ success: true, memory_id });
  } catch (err) {
    console.error('Error storing memory:', err);
    res.status(500).json({ error: 'Failed to store memory', details: err.message });
  }
});

// Retrieve Memory by Context
app.get('/api/v1/memory/:context', async (req, res) => {
  const { context } = req.params;
  const { limit = 10 } = req.query;

  try {
    const query = `
      SELECT memory_id, timestamp, tags, payload 
      FROM \`${datasetId}.${tableId}\`
      WHERE context = @context
      ORDER BY timestamp DESC
      LIMIT @limit
    `;

    const options = {
      query: query,
      params: { context, limit: parseInt(limit) }
    };

    const [rows] = await bigquery.query(options);
    
    // Parse JSON payloads
    const memories = rows.map(r => ({
      ...r,
      payload: typeof r.payload === 'string' ? JSON.parse(r.payload) : r.payload
    }));

    res.json({ context, count: memories.length, memories });
  } catch (err) {
    console.error('Error retrieving memory:', err);
    res.status(500).json({ error: 'Failed to retrieve memory', details: err.message });
  }
});

const PORT = parseInt(process.env.PORT) || 8080;
const server = app.listen(PORT, '0.0.0.0', () => {
  console.log(`CEREBRO Quantum Memory listening on port ${PORT}`);
});

process.on('SIGTERM', () => {
  console.log('[SHUTDOWN] SIGTERM received. Closing HTTP server...');
  server.close(() => {
    console.log('[SHUTDOWN] HTTP server closed.');
    process.exit(0);
  });
});
