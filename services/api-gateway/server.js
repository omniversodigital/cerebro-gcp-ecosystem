const express = require('express');
const { PubSub } = require('@google-cloud/pubsub');
const { SecretManagerServiceClient } = require('@google-cloud/secret-manager');
const { BigQuery } = require('@google-cloud/bigquery');
const cors = require('cors');

const app = express();
const pubsub = new PubSub();
const secrets = new SecretManagerServiceClient();
const bigquery = new BigQuery();

app.use(cors());
app.use(express.json({ limit: '10mb' }));

// ── Correlation ID & Structured Logging Middleware ──
app.use((req, res, next) => {
  const correlationId = req.headers['x-correlation-id'] || req.headers['x-request-id'] || `trace-${Date.now()}-${Math.random().toString(36).substring(2, 9)}`;
  req.correlationId = correlationId;
  res.setHeader('X-Correlation-ID', correlationId);

  const startTime = Date.now();
  res.on('finish', () => {
    const durationMs = Date.now() - startTime;
    console.log(JSON.stringify({
      timestamp: new Date().toISOString(),
      level: res.statusCode >= 400 ? 'WARN' : 'INFO',
      service: 'cerebro-api-gateway',
      traceId: correlationId,
      method: req.method,
      path: req.path,
      statusCode: res.statusCode,
      durationMs,
      userAgent: req.headers['user-agent'] || 'unknown'
    }));
  });

  next();
});

// ── Health Check ──
app.get('/health', (req, res) => {
  res.json({
    status: 'operational',
    service: 'cerebro-api-gateway',
    version: '1.0.0',
    timestamp: new Date().toISOString(),
    traceId: req.correlationId,
    uptime: process.uptime()
  });
});

// ── Ecosystem Status ──
app.get('/api/v1/status', async (req, res) => {
  try {
    const status = {
      gateway: 'online',
      timestamp: new Date().toISOString(),
      services: {
        pubsub: 'checking',
        secrets: 'checking'
      }
    };

    // Check Pub/Sub connectivity
    try {
      const [topics] = await pubsub.getTopics();
      status.services.pubsub = 'online';
      status.pubsubTopics = topics.length;
    } catch {
      status.services.pubsub = 'offline';
    }

    res.json(status);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// ── Publish Command ──
app.post('/api/v1/commands', async (req, res) => {
  const { command, target, payload, priority = 'normal' } = req.body;

  if (!command) {
    return res.status(400).json({ error: 'command is required' });
  }

  const message = {
    command,
    target: target || 'default',
    payload: payload || {},
    priority,
    timestamp: new Date().toISOString(),
    source: 'api-gateway',
    traceId: `cmd-${Date.now()}-${Math.random().toString(36).substr(2, 9)}`
  };

  try {
    const topicName = 'cerebro-commands';
    const topic = pubsub.topic(topicName);
    const [exists] = await topic.exists();

    if (!exists) {
      await topic.create();
    }

    const messageId = await topic.publishMessage({
      data: Buffer.from(JSON.stringify(message)),
      attributes: {
        command,
        priority,
        source: 'api-gateway'
      }
    });

    res.status(202).json({
      accepted: true,
      messageId,
      traceId: message.traceId,
      topic: topicName
    });
  } catch (err) {
    console.error('Publish error:', err);
    res.status(500).json({ error: 'Failed to publish command', details: err.message });
  }
});

// ── Publish Market Signal ──
app.post('/api/v1/signals/market', async (req, res) => {
  const { symbol, action, source, confidence, metadata } = req.body;

  if (!symbol || !action) {
    return res.status(400).json({ error: 'symbol and action are required' });
  }

  const signal = {
    symbol,
    action,
    source: source || 'manual',
    confidence: confidence || 0.5,
    metadata: metadata || {},
    timestamp: new Date().toISOString(),
    traceId: `sig-${Date.now()}-${Math.random().toString(36).substr(2, 9)}`
  };

  try {
    const topic = pubsub.topic('market-signals');
    const [exists] = await topic.exists();
    if (!exists) await topic.create();

    const messageId = await topic.publishMessage({
      data: Buffer.from(JSON.stringify(signal)),
      attributes: { symbol, action, source: signal.source }
    });

    res.status(202).json({ accepted: true, messageId, traceId: signal.traceId });
  } catch (err) {
    res.status(500).json({ error: 'Failed to publish signal', details: err.message });
  }
});

// ── Publish Security Alert ──
app.post('/api/v1/alerts/security', async (req, res) => {
  const { severity, type, description, source, metadata } = req.body;

  if (!severity || !type) {
    return res.status(400).json({ error: 'severity and type are required' });
  }

  const alert = {
    severity,
    type,
    description: description || '',
    source: source || 'manual',
    metadata: metadata || {},
    timestamp: new Date().toISOString(),
    traceId: `sec-${Date.now()}-${Math.random().toString(36).substr(2, 9)}`
  };

  try {
    const topic = pubsub.topic('security-alerts');
    const [exists] = await topic.exists();
    if (!exists) await topic.create();

    const messageId = await topic.publishMessage({
      data: Buffer.from(JSON.stringify(alert)),
      attributes: { severity, type, source: alert.source }
    });

    res.status(202).json({ accepted: true, messageId, traceId: alert.traceId });
  } catch (err) {
    res.status(500).json({ error: 'Failed to publish alert', details: err.message });
  }
});

// ── Ecosystem Events ──
app.post('/api/v1/events', async (req, res) => {
  const { eventType, data, source } = req.body;

  if (!eventType) {
    return res.status(400).json({ error: 'eventType is required' });
  }

  const event = {
    eventType,
    data: data || {},
    source: source || 'api-gateway',
    timestamp: new Date().toISOString(),
    traceId: `evt-${Date.now()}-${Math.random().toString(36).substr(2, 9)}`
  };

  try {
    const topic = pubsub.topic('ecosystem-events');
    const [exists] = await topic.exists();
    if (!exists) await topic.create();

    const messageId = await topic.publishMessage({
      data: Buffer.from(JSON.stringify(event)),
      attributes: { eventType, source: event.source }
    });

    res.status(202).json({ accepted: true, messageId, traceId: event.traceId });
  } catch (err) {
    res.status(500).json({ error: 'Failed to publish event', details: err.message });
  }
});

// ── Secret Access (restricted) ──
app.get('/api/v1/secrets/:name', async (req, res) => {
  const { name } = req.params;
  const { version = 'latest' } = req.query;

  try {
    const project = process.env.GOOGLE_CLOUD_PROJECT || process.env.GCP_PROJECT;
    const [secret] = await secrets.accessSecretVersion({
      name: `projects/${project}/secrets/${name}/versions/${version}`
    });

    res.json({
      name,
      version,
      payload: secret.payload.data.toString('utf8'),
      accessedAt: new Date().toISOString()
    });
  } catch (err) {
    if (err.code === 5) {
      return res.status(404).json({ error: `Secret '${name}' not found` });
    }
    res.status(500).json({ error: 'Failed to access secret', details: err.message });
  }
});

// ── Ledger (Quantum Memory Proxy) ──
app.get('/api/v1/ledger', async (req, res) => {
  try {
    const limit = parseInt(req.query.limit) || 20;
    const query = `
      SELECT context, payload, tags, timestamp 
      FROM \`gen-lang-client-0722648923.cerebro_omega.quantum_memory\`
      WHERE 'trade_execution' IN UNNEST(tags)
      ORDER BY timestamp DESC
      LIMIT @limit
    `;
    const options = {
      query: query,
      params: { limit },
    };
    const [rows] = await bigquery.query(options);
    res.json(rows);
  } catch (err) {
    console.error('Ledger query error:', err);
    res.status(500).json({ error: 'Failed to fetch ledger from Quantum Memory', details: err.message });
  }
});

// ── Error handler ──
app.use((err, req, res, next) => {
  console.error('Unhandled error:', err);
  res.status(500).json({
    error: 'Internal server error',
    message: process.env.NODE_ENV === 'development' ? err.message : undefined
  });
});

const PORT = parseInt(process.env.PORT) || 8080;
app.listen(PORT, '0.0.0.0', () => {
  console.log(`CEREBRO API Gateway listening on port ${PORT}`);
  console.log(`Environment: ${process.env.NODE_ENV || 'development'}`);
  console.log(`Project: ${process.env.GOOGLE_CLOUD_PROJECT || 'not set'}`);
});

module.exports = app;
