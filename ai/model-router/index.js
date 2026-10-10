const express = require('express');

const app = express();
app.use(express.json());

/**
 * CEREBRO AI Model Router
 * 
 * Intelligent routing between AI models based on task complexity,
 * latency requirements, and cost optimization.
 * 
 * Models:
 * - Gemini Flash: Fast, cheap — simple tasks, classification, summarization
 * - Gemini Pro: Balanced — complex analysis, code generation
 * - DeepSeek R1: Reasoning — math, logic, complex problem solving
 * - OpenRouter: Fallback — access to 100+ models
 */

const MODEL_PROFILES = {
  'gemini-flash': {
    endpoint: 'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent',
    maxTokens: 8192,
    costPer1kInput: 0.0001,
    costPer1kOutput: 0.0004,
    avgLatencyMs: 800,
    capabilities: ['fast', 'summarization', 'classification', 'extraction'],
    priority: 1
  },
  'gemini-pro': {
    endpoint: 'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-pro:generateContent',
    maxTokens: 65536,
    costPer1kInput: 0.00125,
    costPer1kOutput: 0.005,
    avgLatencyMs: 3000,
    capabilities: ['reasoning', 'code', 'analysis', 'creative', 'complex'],
    priority: 2
  },
  'deepseek-r1': {
    endpoint: 'http://localhost:11434/api/generate',
    maxTokens: 32768,
    costPer1kInput: 0,
    costPer1kOutput: 0,
    avgLatencyMs: 5000,
    capabilities: ['reasoning', 'math', 'logic', 'proof'],
    priority: 3,
    local: true
  },
  'fable-5': {
    endpoint: process.env.CEREBRO_FABLE_ENDPOINT || 'https://api.fable.ai/v1/chat/completions',
    apiKeyEnv: 'CEREBRO_FABLE_API_KEY',
    maxTokens: 128000,
    costPer1kInput: 0.005,
    costPer1kOutput: 0.015,
    avgLatencyMs: 2500,
    capabilities: ['storytelling', 'creative', 'complex', 'reasoning'],
    priority: 4
  }
};

// Route selection logic
function selectModel(taskType, constraints = {}) {
  const { maxLatencyMs, maxCostUsd, preferLocal, requiredCapability } = constraints;

  let candidates = Object.entries(MODEL_PROFILES);

  // Filter by required capability
  if (requiredCapability) {
    candidates = candidates.filter(([, p]) => p.capabilities.includes(requiredCapability));
  }

  // Filter by latency constraint
  if (maxLatencyMs) {
    candidates = candidates.filter(([, p]) => p.avgLatencyMs <= maxLatencyMs);
  }

  // Prefer local if requested
  if (preferLocal) {
    const localModels = candidates.filter(([, p]) => p.local);
    if (localModels.length > 0) candidates = localModels;
  }

  // Sort by priority (lower = preferred)
  candidates.sort((a, b) => a[1].priority - b[1].priority);

  // Task-type heuristics
  const taskMapping = {
    'summarize': 'gemini-flash',
    'classify': 'gemini-flash',
    'extract': 'gemini-flash',
    'translate': 'gemini-flash',
    'analyze': 'gemini-pro',
    'code': 'gemini-pro',
    'creative': 'gemini-pro',
    'reason': 'deepseek-r1',
    'math': 'deepseek-r1',
    'proof': 'deepseek-r1'
  };

  if (taskType && taskMapping[taskType]) {
    const mapped = taskMapping[taskType];
    if (candidates.find(([name]) => name === mapped)) {
      return { model: mapped, profile: MODEL_PROFILES[mapped], reason: `task_type_match: ${taskType}` };
    }
  }

  if (candidates.length === 0) {
    return { model: 'gemini-pro', profile: MODEL_PROFILES['gemini-pro'], reason: 'fallback_default' };
  }

  return { model: candidates[0][0], profile: candidates[0][1], reason: 'best_available' };
}

// ── Routes ──

app.get('/health', (req, res) => {
  res.json({ status: 'operational', service: 'cerebro-model-router', models: Object.keys(MODEL_PROFILES) });
});

app.post('/api/v1/route', (req, res) => {
  const { taskType, prompt, constraints } = req.body;

  if (!prompt) {
    return res.status(400).json({ error: 'prompt is required' });
  }

  const selection = selectModel(taskType, constraints || {});

  res.json({
    selectedModel: selection.model,
    reason: selection.reason,
    profile: {
      maxTokens: selection.profile.maxTokens,
      estimatedLatencyMs: selection.profile.avgLatencyMs,
      estimatedCostPer1k: selection.profile.costPer1kInput + selection.profile.costPer1kOutput,
      capabilities: selection.profile.capabilities
    }
  });
});

app.get('/api/v1/models', (req, res) => {
  const models = Object.entries(MODEL_PROFILES).map(([name, profile]) => ({
    name,
    capabilities: profile.capabilities,
    avgLatencyMs: profile.avgLatencyMs,
    costPer1kTokens: profile.costPer1kInput + profile.costPer1kOutput,
    local: profile.local || false
  }));

  res.json({ models });
});

const PORT = parseInt(process.env.PORT) || 8084;
app.listen(PORT, '0.0.0.0', () => {
  console.log(`CEREBRO Model Router listening on port ${PORT}`);
});

module.exports = { app, selectModel, MODEL_PROFILES };
