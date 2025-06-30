// Set environment variables before requiring newrelic
process.env.NEW_RELIC_ENABLED = true;
process.env.NEW_RELIC_APP_NAME = 'Banking API Gateway';
process.env.NEW_RELIC_LICENSE_KEY = '59829ffc48a17aa6783a0ee3cd15e230FFFFNRAL';

// Require New Relic agent
const newrelic = require('newrelic');

const express = require('express');
const { createProxyMiddleware } = require('http-proxy-middleware');
const morgan = require('morgan');
const prometheus = require('prom-client');

// Force New Relic to be enabled
newrelic.agent.config.enabled = true;

console.log('New Relic enabled status:', newrelic.agent.config.enabled);

// Create a Registry to register metrics
const register = new prometheus.Registry();
prometheus.collectDefaultMetrics({ register });

// Create custom metrics
const httpRequestDurationMicroseconds = new prometheus.Histogram({
  name: 'http_request_duration_seconds',
  help: 'Duration of HTTP requests in seconds',
  labelNames: ['method', 'route', 'code'],
  buckets: [0.1, 0.3, 0.5, 0.7, 1, 3, 5, 7, 10]
});

// Register the metrics
register.registerMetric(httpRequestDurationMicroseconds);

const app = express();
const PORT = 8080;

// Logging middleware
app.use(morgan('combined'));

// Force transaction creation for every request
app.use((req, res, next) => {
  try {
    const path = req.path || 'unknown';
    const segment = newrelic.getTransaction().getSegment();
    newrelic.setTransactionName('WebTransaction/Custom/' + path);
    console.log('Set transaction name for path:', path);
  } catch (err) {
    console.error('New Relic transaction error:', err);
  }
  next();
});

// Prometheus middleware to measure request duration
app.use((req, res, next) => {
  const end = httpRequestDurationMicroseconds.startTimer();
  res.on('finish', () => {
    end({ method: req.method, route: req.path, code: res.statusCode });
  });
  next();
});

// Expose metrics endpoint for Prometheus
app.get('/metrics', async (req, res) => {
  res.set('Content-Type', register.contentType);
  res.end(await register.metrics());
});

// Account Service Proxy
app.use('/accounts', createProxyMiddleware({
  target: process.env.ACCOUNT_SERVICE_URL || 'http://localhost:8081',
  changeOrigin: true,
  pathRewrite: {'^/accounts': '/'}
}));

// Transaction Service Proxy
app.use('/transactions', createProxyMiddleware({
  target: process.env.TRANSACTION_SERVICE_URL || 'http://localhost:8082',
  changeOrigin: true,
  pathRewrite: {'^/transactions': '/'}
}));

// Auth Service Proxy
app.use('/auth', createProxyMiddleware({
  target: process.env.AUTH_SERVICE_URL || 'http://localhost:8083',
  changeOrigin: true,
  pathRewrite: {'^/auth': '/'}
}));

// Notification Service Proxy
app.use('/notifications', createProxyMiddleware({
  target: process.env.NOTIFICATION_SERVICE_URL || 'http://localhost:8084',
  changeOrigin: true,
  pathRewrite: {'^/notifications': '/'}
}));

// Fraud Detection Service Proxy
app.use('/fraud', createProxyMiddleware({
  target: process.env.FRAUD_SERVICE_URL || 'http://localhost:8085',
  changeOrigin: true,
  pathRewrite: {'^/fraud': '/'}
}));

// Health check endpoint
app.get('/health', (req, res) => {
  try {
    newrelic.recordCustomEvent('HealthCheck', {status: 'UP', timestamp: Date.now()});
    console.log('Recorded custom event for health check');
  } catch (err) {
    console.error('New Relic event error:', err);
  }
  res.status(200).json({ status: 'UP' });
});

app.listen(PORT, () => {
  console.log(`API Gateway running on port ${PORT}`);
  console.log('New Relic status:', newrelic.agent.config.enabled ? 'ENABLED' : 'DISABLED');
});
