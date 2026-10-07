// notification-service: tells customers that their trade was accepted (simulated).
//
// Deployed LATER in the Day 3 demo, after the platform is running. The image contains no
// OpenTelemetry code or packages: the OpenTelemetry Operator injects Node.js
// auto-instrumentation when the pod is created (annotation instrumentation.opentelemetry.io/inject-nodejs).
// trade-api already calls this service, so its spans appear inside existing trade traces.
'use strict';

const express = require('express');

const app = express();
app.use(express.json());

const PORT = process.env.PORT || 3000;

function log(level, message) {
  console.log(`${new Date().toISOString()} ${level} [notification-service] ${message}`);
}

app.post('/api/notifications', (req, res) => {
  const { tradeId, customerEmail, symbol, side, quantity } = req.body || {};
  // Simulated call to an e-mail / push gateway: 10-40 ms.
  const delay = 10 + Math.floor(Math.random() * 30);
  setTimeout(() => {
    log('INFO', `Notification sent to ${customerEmail} for trade ${tradeId}: ${side} ${symbol} x ${quantity}`);
    res.status(202).json({ status: 'SENT', tradeId });
  }, delay);
});

app.get('/health', (_req, res) => res.send('ok'));

app.listen(PORT, () => log('INFO', `listening on port ${PORT}`));
